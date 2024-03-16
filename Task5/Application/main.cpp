#include <stdio.h>
#include <opencv2/opencv.hpp>
#include "DCT.h"
#include <chrono>

using namespace cv;

int dctIPCoreTest()
{
    std::uint8_t counter = 32;
    std::array<std::array<std::uint8_t,32>,16> pixels;
    for(uint blockCol=0; blockCol<4; blockCol++)
    {
        for(uint blockRow=0; blockRow<2; blockRow++)
        {
            uint blockOffsetCol = blockCol*8;
            uint blockOffsetRow = blockRow*8;
            std::cout<<"Block :"<<blockCol*4+blockRow<<std::endl;

            for(uint pxLocRow=0; pxLocRow<8; pxLocRow++)
            {
                for(uint pxLocCol=0; pxLocCol<8; pxLocCol++)
                {
                    uint col = blockOffsetCol+pxLocCol;
                    uint row = blockOffsetRow+pxLocRow;
                    pixels[row][col] = counter;
                    counter++;
                    std::cout<<" "<<int(pixels[row][col]);
                }
                std::cout<<std::endl;
                
            }
        }
    }
    cv::Mat testImage(16,32,CV_8UC1);
    for(uint y=0; y<pixels.size(); y++)
    {
        for(uint x=0; x<pixels[y].size(); x++)
        {
            testImage.at<uchar>(y,x) = pixels[y][x];
        }
    }
    std::cout<<"testImage.at<uchar>(0,0):"<<int(testImage.at<uchar>(0,0))<<std::endl;
    std::unique_ptr<cv::Mat> resultImage = applyDCTPassthrough(testImage);
    for(uint blockColInd=0; blockColInd<4; blockColInd++)
    {
        for(uint blockRowInd=0; blockRowInd<2; blockRowInd++)
        {
            uint blockColOffset = blockColInd*8;
            uint blockRowOffset = blockRowInd*8;
            std::cout<<"Block :"<<blockColInd*4+blockRowInd<<std::endl;
            for(uint row=blockRowOffset; row<blockRowOffset+8; row++)
            {
                for(uint col=blockColOffset; col<blockColOffset+8; col++)
                {
                    std::cout<<" "<<resultImage->at<short>(row,col);
                }
                std::cout<<std::endl;
            }
        }
    }
    return 0;
}

int processImageFile(int argc, char** argv )
{
    if ( argc != 2 )
    {
        printf("usage: DisplayImage.out <Image_Path>\n");
        return -1;
    }
    Mat image, greyImage;
    image = imread( argv[1], IMREAD_COLOR );
    if ( !image.data )
    {
        printf("No image data \n");
        return -1;
    }
    cv::cvtColor(image, greyImage, cv::COLOR_BGR2GRAY);
    
    std::unique_ptr<cv::Mat> output = applyDCTPassthrough(greyImage);
    
    namedWindow("Display Image", WINDOW_AUTOSIZE );
    imshow("Display Image", greyImage);
    imshow("Output Image", *output);
    waitKey(0);
    return 0;
}

int testDriver()
{
	int fd_dct = open("/dev/misc_dct",O_RDWR);
    	if(fd_dct<0)
	{
		printf("Failed to open dct device\n");
		throw std::logic_error("Failed to open device");
	}

	
	uint32_t status;
	ioctl(fd_dct,IOCTL_DCTSTATUS,&status);
	std::cout<<"status:"<<status<<std::endl;

	uint32_t numBlocks = 20000;
	uint8_t counter=32;
	std::vector<uint8_t> dataIn;
	for(uint blockId=0; blockId<numBlocks; blockId++)
	{
		for(uint pxInd=0; pxInd<64; pxInd++)
		{
			if(blockId<numBlocks/2)
			{
				dataIn.push_back(counter);
				counter++;
			}
			else
			{
				dataIn.push_back(255);
			}
		}
		std::cout<<std::endl;
	}

	std::cout<<"In Blocks"<<std::endl;
	for(uint i=0; i<numBlocks; i++)
	{
		for(uint j=0; j<8; j++)
		{
			for(uint k=0; k<8; k++)
			{	
				printf("%4d ",int(dataIn[i*64+j*8+k]));
			}
			std::cout<<std::endl;
		}
		std::cout<<std::endl;
	}

	rotate128Beat(dataIn);
	
	ioctl(fd_dct,IOCTL_DCTNUMBLOCKS,&numBlocks);

	ioctl(fd_dct,IOCTL_DCTDMAMALLOC);
	
	ioctl(fd_dct,IOCTL_DCTINPUTDATA,dataIn.data());

	auto startTime = std::chrono::high_resolution_clock::now();

	ioctl(fd_dct,IOCTL_DCTEXECCMD);

	ioctl(fd_dct,IOCTL_DCTWAIT);

	auto endTime = std::chrono::high_resolution_clock::now();

	std::vector<int16_t> outData;
	outData.resize(numBlocks*64);
	ioctl(fd_dct,IOCTL_DCTOUTPUTDATA,outData.data());

	rotate128Beat(outData);

	for(uint i=0; i<numBlocks; i++)
	{
		for(uint j=0;j<8;j++)
		{
			for(uint k=0; k<8; k++)
			{
				printf("%4d ",outData[i*64+j*8+k]);
			}
			std::cout<<std::endl;
		}
		std::cout<<std::endl;
	}

	ioctl(fd_dct,IOCTL_DCTDMAFREE);
	
	close(fd_dct);


	return 0;
}

int evaluateIPCoreRuntime()
{
	int fd_dct = open("/dev/misc_dct",O_RDWR);
    	if(fd_dct<0)
	{
		printf("Failed to open dct device\n");
		throw std::logic_error("Failed to open device");
	}

	
	uint32_t status;
	ioctl(fd_dct,IOCTL_DCTSTATUS,&status);
	std::cout<<"status:"<<status<<std::endl;

	uint32_t maxTestBlocks = 1048576;
	uint32_t currNumberBlocks = 1;

	while(currNumberBlocks <= maxTestBlocks)
	{
		uint8_t counter=32;
		std::vector<uint8_t> dataIn;
		for(uint blockId=0; blockId<currNumberBlocks; blockId++)
		{
			for(uint pxInd=0; pxInd<64; pxInd++)
			{
				if(blockId<currNumberBlocks/2)
				{
					dataIn.push_back(counter);
					counter++;
				}
				else
				{
					dataIn.push_back(255);
				}
			}
		}

		rotate128Beat(dataIn);
	
		ioctl(fd_dct,IOCTL_DCTNUMBLOCKS,&currNumberBlocks);

		ioctl(fd_dct,IOCTL_DCTDMAMALLOC);
	
		ioctl(fd_dct,IOCTL_DCTINPUTDATA,dataIn.data());

		auto startTime = std::chrono::high_resolution_clock::now();

		ioctl(fd_dct,IOCTL_DCTEXECCMD);

		//ioctl(fd_dct,IOCTL_DCTWAIT);

		auto endTime = std::chrono::high_resolution_clock::now();

		std::vector<int16_t> outData;
		outData.resize(currNumberBlocks*64);
		ioctl(fd_dct,IOCTL_DCTOUTPUTDATA,outData.data());

		rotate128Beat(outData);

		ioctl(fd_dct,IOCTL_DCTDMAFREE);

		auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(endTime-startTime);
		std::cout<<"Running "<<currNumberBlocks<<" blocks took "<<duration.count()<<" milliseconds."<<std::endl;

		currNumberBlocks = currNumberBlocks*2;
	}
	
	close(fd_dct);

	return 0;
}

int main(int argc, char** argv )
{
    return evaluateIPCoreRuntime();
}
