#include <stdio.h>
#include <opencv2/opencv.hpp>
#include "DCT.h"

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

int main(int argc, char** argv )
{
    return dctIPCoreTest();
}
