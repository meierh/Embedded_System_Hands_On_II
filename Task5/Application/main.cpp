#include <stdio.h>
#include <opencv2/opencv.hpp>
#include "DCT.h"
#include <chrono>

int processImageFile(int argc, char** argv )
{
    if ( argc < 3 )
    {
        printf("usage: DisplayImage.out <Image_Path> <Image_Path>\n");
        return -1;
    }
    cv::Mat image, greyImage;
    image = cv::imread( argv[1], cv::IMREAD_COLOR );
    if ( !image.data )
    {
        printf("No image data \n");
        return -1;
    }
    cv::cvtColor(image, greyImage, cv::COLOR_BGR2GRAY);
    
    ComputeMode mode = (argc>3)?ComputeMode::Software:ComputeMode::Hardware;
    std::unique_ptr<cv::Mat> output = applyDCT(greyImage,mode);
	
    cv::imwrite( argv[2] , *output);
    
    return 0;
}

int testFPGA()
{
	int fd_dct = open("/dev/misc_dct",O_RDWR);
	if(fd_dct<0)
	{
		printf("Failed to open dct device\n");
		throw std::logic_error("Failed to open device");
	}

	uint32_t numBlocks = 2;
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

	std::vector<int16_t> softwareBlocks(dataIn.size());
	softwareDCT(dataIn,softwareBlocks);

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
	
	std::cout<<"Hardware Blocks"<<std::endl;
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
	
	std::cout<<"Software Blocks"<<std::endl;
	for(uint i=0; i<numBlocks; i++)
	{
		for(uint j=0; j<8; j++)
		{
			for(uint k=0; k<8; k++)
			{
				printf("%4d ",softwareBlocks[i*64+j*8+k]);
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
		std::cout<<"FPGA computing "<<currNumberBlocks<<" blocks took "<<duration.count()<<" milliseconds."<<std::endl;

		currNumberBlocks = currNumberBlocks*2;
	}
	
	close(fd_dct);

	return 0;
}

int evaluateCPURuntime()
{
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

		std::vector<int16_t> outData;
		outData.resize(currNumberBlocks*64);
		
		auto startTime = std::chrono::high_resolution_clock::now();

		softwareDCT(dataIn,outData);

		auto endTime = std::chrono::high_resolution_clock::now();


		auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(endTime-startTime);
		std::cout<<"CPU computing "<<currNumberBlocks<<" blocks took "<<duration.count()<<" milliseconds."<<std::endl;

		currNumberBlocks = currNumberBlocks*2;
	}
	return 0;
}

int main(int argc, char** argv )
{
	if(argc<3)
	{
		std::cout<<"-------------Test correctness of FPGA-------------"<<std::endl;
		testFPGA();
		std::cout<<std::endl<<"-------------Test runtime of FPGA-------------"<<std::endl;
		evaluateIPCoreRuntime();
		std::cout<<std::endl<<"-------------Test runtime of CPU-------------"<<std::endl;
		evaluateCPURuntime();
	}
	if(argc>=3)
	{
		std::cout<<std::endl<<"---------Test with real image on FPGA-------------"<<std::endl;
		processImageFile(argc,argv);
	}
    return 0;
}
