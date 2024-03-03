#include <stdio.h>
#include <opencv2/opencv.hpp>
#include "SobelFilter.h"

using namespace cv;
int main(int argc, char** argv )
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
