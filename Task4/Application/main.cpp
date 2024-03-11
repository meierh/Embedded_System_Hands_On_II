#include <stdio.h>
#include <opencv2/opencv.hpp>
#include "SobelFilter.h"

using namespace cv;

int sobelIPCoreTest()
{
    std::array<std::array<std::uint8_t,18>,7> pixels;    
    std::uint8_t counter = 1;
    for(uint y=0; y<7; y++)
    {
        for(uint x=0; x<20; x++)
        {
            pixels[y][x] = counter;
            counter++;
        }
    }
    for(auto& row : pixels)
    {
        for(uint i=0; i<row.size(); i++)
        {
            printf(" %3d",int(row[i]));
        }
        printf("\n");
    }
    std::cout<<"---------------------------------------"<<std::endl;
    
    cv::Mat testImage(7,18,CV_8UC1);
    for(uint y=0; y<pixels.size(); y++)
    {
        for(uint x=0; x<pixels[y].size(); x++)
        {
            testImage.at<uchar>(y,x) = pixels[y][x];
        }
    }
    std::unique_ptr<cv::Mat> result = applySobelFilter(testImage);
    
    for(uint y=0; y<result->rows; y++)
    {
        for(uint x=0; x<result->cols; x++)
        {
            printf(" %3d",int(testImage.at<uchar>(y,x)));
        }
        printf("\n");
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
    
    std::unique_ptr<cv::Mat> output = applySobelFilter(greyImage);
    
    namedWindow("Display Image", WINDOW_AUTOSIZE );
    imshow("Display Image", greyImage);
    imshow("Output Image", *output);
    waitKey(0);
    return 0;
}

int main(int argc, char** argv )
{
    return sobelIPCoreTest();
}
