#include <stdio.h>
#include <opencv2/opencv.hpp>
#include "SobelFilter.h"
#include "../Driver/ioctl_sobel.h"

using namespace cv;

int processImageFile(int argc, char** argv )
{
    if ( argc < 3 )
    {
        printf("usage: DisplayImage.out <Image_Path> <Image_Path>\n");
        return -1;
    }
    cv::Mat image, greyImage;
    image = cv::imread( argv[1], IMREAD_COLOR );
    if ( !image.data )
    {
        printf("No image data \n");
        return -1;
    }
    cv::cvtColor(image, greyImage, cv::COLOR_BGR2GRAY);
    
    /*
    greyImage = cv::Mat(5,10,CV_8U);
    uint counter = 1;
    for(uint x=0; x<10; x++)
        for(uint y=0; y<5; y++)
        {
            greyImage.at<uchar>(y,x) = counter;
            counter++;
        }
        
    for(uint y=0; y<greyImage.rows; y++)
    {
        for(uint x=0; x<greyImage.cols; x++)
        {
            printf("%3d",greyImage.at<uchar>(y,x));
        }
        std::cout<<std::endl;
    }
    std::cout<<std::endl;
    */
    std::unique_ptr<cv::Mat> output = applySobelFilter(greyImage);
    
    /*
    for(uint y=0; y<output->rows; y++)
    {
        for(uint x=0; x<output->cols; x++)
        {
            printf("%3d",output->at<uchar>(y,x));
        }
        std::cout<<std::endl;
    }
    std::cout<<std::endl;
    */
    cv::imwrite( argv[2] , *output);

    return 0;
}

int testFPGA()
{
    int fd_sobel = open("/dev/misc_sobel",O_RDWR);
    if(fd_sobel<0)
    {
        printf("Failed to open sobel device\n");
        throw std::logic_error("Failed to open device");
    }

    constexpr uint32_t numChunks = 2;
    constexpr uint32_t resY = 6;
    constexpr uint32_t paddedResY = resY+2*3;
    std::array<std::array<uint8_t,(numChunks-1)*10+16>,paddedResY> image;
    std::for_each(image.begin(),image.end(),[](auto& line){std::fill(line.begin(),line.end(),0);});

    uint8_t counter=0;
    for(uint y=0; y<resY; y++)
    {
        for(uint x=0; x<(numChunks-1)*10+16-2*3; x++)
        {
            image[y+3][x+3] = counter;
            counter++;
        }
    }

    std::cout<<"Image"<<std::endl;
    for(const std::array<uint8_t,(numChunks-1)*10+16>& row : image)
    {
        for(uint8_t px : row)
        {
            printf("%3d ",px);
        }
        std::cout<<std::endl;
    }
    std::cout<<std::endl;
    

    std::vector<std::array<uint8_t,16>> chunks;
    uint32_t offsetX = 0;
    for(uint chunkId=0; chunkId<numChunks; chunkId++,offsetX+=10)
    {
        for(uint row=0; row<image.size(); row++)
        {
            std::array<uint8_t,16> chunk;
            std::memcpy(chunk.data(),image[row].data()+offsetX,16);
            chunks.push_back(chunk);
        }
    }

    std::cout<<"Image chunks"<<std::endl;
    for(const std::array<uint8_t,16>& row : chunks)
    {
        for(uint8_t px : row)
        {
            printf("%3d ",px);
        }
        std::cout<<std::endl;
    }
    std::cout<<std::endl;
    
    std::vector<uint8_t> bytes;
    uint8_t counterL = 1;
    for(const std::array<uint8_t,16>& chunk : chunks)
    {
        for(uint8_t pixel : chunk)
        {
            bytes.push_back(pixel);;
        }
    }
        
    rotate128Beat(bytes);

    ioctl(fd_sobel,IOCTL_SOBELWAIT);
    
    ioctl(fd_sobel,IOCTL_SOBELCHUNKSX,&numChunks);
    ioctl(fd_sobel,IOCTL_SOBELRESY,&paddedResY);
    uint32_t kernelType = 0;
    ioctl(fd_sobel,IOCTL_SOBELKERNEL,&kernelType);
 
    ioctl(fd_sobel,IOCTL_SOBELDMAMALLOC);

    ioctl(fd_sobel,IOCTL_SOBELINPUTDATA,bytes.data());

    auto startTime = std::chrono::high_resolution_clock::now();

    ioctl(fd_sobel,IOCTL_SOBELEXECCMD);
    ioctl(fd_sobel,IOCTL_SOBELWAIT);

    auto endTime = std::chrono::high_resolution_clock::now();

    std::vector<uint8_t> outData;
    outData.resize(numChunks*resY*16);
    
    ioctl(fd_sobel,IOCTL_SOBELOUTPUTDATA,outData.data());

    rotate128Beat(outData);

    ioctl(fd_sobel,IOCTL_SOBELDMAFREE);

    std::cout<<"Output chunks"<<std::endl;
    for(uint i=0; i<outData.size(); i+=16)
    {
        for(uint j=0;j<16;j++)
        {
            printf("%3d ",int(outData[i+j]));
        }
        std::cout<<std::endl;   
    }

    close(fd_sobel);

    return 0;
}

int evaluateIPCoreRuntime()
{
    int fd_sobel = open("/dev/misc_sobel",O_RDWR);
    if(fd_sobel<0)
    {
	printf("Failed to open sobel device\n");
	throw std::logic_error("Failed to open device");
    }
	
    uint32_t maxPixelCount = 500000000;
    
    uint32_t chunkCount = 1;
    uint32_t resYNum = 5;
        
    uint32_t currPixelCount = resYNum*((chunkCount-1)*10+16);

    while(currPixelCount <= maxPixelCount)
    {
        uint32_t paddedResY = resYNum+2*3;
        std::vector<std::vector<uint8_t>> image(paddedResY);
        std::for_each(image.begin(),image.end(),[&](auto& line){line.resize((chunkCount-1)*10+16);std::fill(line.begin(),line.end(),0);});

        uint8_t counter=0;
        for(uint y=0; y<resYNum; y++)
        {
            for(uint x=0; x<(chunkCount-1)*10+16-2*3; x++)
            {
                image[y+3][x+3] = counter;
                counter++;
            }
        }    


        std::vector<std::array<uint8_t,16>> chunks;
        uint32_t offsetX = 0;
        for(uint chunkId=0; chunkId<chunkCount; chunkId++,offsetX+=10)
        {
            for(uint row=0; row<image.size(); row++)
            {
                std::array<uint8_t,16> chunk;
                std::memcpy(chunk.data(),image[row].data()+offsetX,16);
                chunks.push_back(chunk);
            }
        }

    
        std::vector<uint8_t> bytes;
        uint8_t counterL = 1;
        for(const std::array<uint8_t,16>& chunk : chunks)
        {
            for(uint8_t pixel : chunk)
            {
                bytes.push_back(pixel);;
            }
        }
               
        rotate128Beat(bytes);

        ioctl(fd_sobel,IOCTL_SOBELWAIT);
        ioctl(fd_sobel,IOCTL_SOBELCHUNKSX,&chunkCount);
        ioctl(fd_sobel,IOCTL_SOBELRESY,&paddedResY);
        uint32_t kernelType = 2;
        ioctl(fd_sobel,IOCTL_SOBELKERNEL,&kernelType);
 
        ioctl(fd_sobel,IOCTL_SOBELDMAMALLOC);

        ioctl(fd_sobel,IOCTL_SOBELINPUTDATA,bytes.data());

        auto startTime = std::chrono::high_resolution_clock::now();
        ioctl(fd_sobel,IOCTL_SOBELEXECCMD);
        ioctl(fd_sobel,IOCTL_SOBELWAIT);
        auto endTime = std::chrono::high_resolution_clock::now();

        std::vector<uint8_t> outData;
        outData.resize(chunkCount*resYNum*16);
    
        ioctl(fd_sobel,IOCTL_SOBELOUTPUTDATA,outData.data());

        rotate128Beat(outData);

        ioctl(fd_sobel,IOCTL_SOBELDMAFREE);
             
        auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(endTime-startTime);
        std::cout<<"Image of dimension (";
        printf("%6d",(chunkCount*10));
        std::cout<<",";
        printf("%6d",resYNum);
        std::cout<<")  and ";
        printf("%9.5f",(( chunkCount*10*resYNum )/(1e6)));
        std::cout<<" megapixels filtered in "<<duration.count()<<" milliseconds"<<std::endl;
        
        chunkCount *= 2;
        resYNum *= 2;
        currPixelCount = resYNum*((chunkCount-1)*10+16);
    }

    close(fd_sobel);
    return 0;
}

int evaluateCPURuntime()
{
    uint32_t maxPixelCount = 3000000000;
    
    uint32_t chunkCount = 1;
    uint32_t resYNum = 5;
        
	uint64_t currPixelCount = resYNum*((chunkCount-1)*10+16);

    while(currPixelCount <= maxPixelCount)
    {
        uint32_t resX = (chunkCount-1)*10+16;
        
        cv::Mat image(resYNum,resX,CV_8U);
        cv::Mat filteredImage;
        auto startTime = std::chrono::high_resolution_clock::now();
        cv::Sobel(image,filteredImage,CV_8U,1,1,7);
        auto endTime = std::chrono::high_resolution_clock::now();
        
        auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(endTime-startTime);
        std::cout<<"Image of dimension (";
        printf("%6d",(chunkCount*10));
        std::cout<<",";
        printf("%6d",resYNum);
        std::cout<<")  and ";
        printf("%10.5f",(( chunkCount*10*resYNum )/(1e6)));
        std::cout<<" megapixels filtered in "<<duration.count()<<" milliseconds"<<std::endl;
        
        chunkCount *= 2;
        resYNum *= 2;
        currPixelCount = resYNum*((chunkCount-1)*10+16);
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
		//evaluateCPURuntime();
	}
	if(argc>=3)
	{
		std::cout<<std::endl<<"---------Test with real image on FPGA-------------"<<std::endl;
		processImageFile(argc,argv);
	}
    return 0;
}
