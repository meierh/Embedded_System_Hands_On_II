#include <opencv2/opencv.hpp>
#include <memory>
#include <sys/ioctl.h>
#include <fcntl.h>
#include <unistd.h>
#include <poll.h>
#include "../Driver/ioctl_dct.h"

enum ComputeMode {Hardware,Software};

/* Function to apply DCT on a cv Mat image. Both software and hardware options available
 */
std::unique_ptr<cv::Mat> applyDCT(cv::Mat input, ComputeMode mode = ComputeMode::Hardware);

/* Expands the image dimensions to fit the chunksize==16 condition
 */
void correctImageSize(cv::Mat&);


/* Generic class for two dimensional array of various types
 */
template<typename T>
class Array2D
{
    public:
        Array2D(uint cols, uint rows);
        T& operator()(uint col, uint row);
        T operator()(uint col, uint row) const;
        uint getCols()const{return cols;}
        uint getRows()const{return rows;}
    private:
        uint cols;
        uint rows;
        std::vector<std::vector<T>> data;
};

//Conversion function from cv Mat to 2d array
std::unique_ptr<Array2D<uchar>> cvGrayscaleToArray(const cv::Mat image);

//Conversion function from 2d array to cv Mat
std::unique_ptr<cv::Mat> arrayToCvGrayscale(const Array2D<int16_t>& array);

template<typename T>
class ImageBlocks
{
    public:        
        ImageBlocks(){};
        ImageBlocks(const Array2D<T>& image);
        ImageBlocks(uint blockRows, uint blockCols);
        void reset(const Array2D<T>& image);
        void reset(uint blockRows, uint blockCols);
        uint getBlockRows()const{return blockRows;}
        uint getBlockCols()const{return blockCols;}
        uint getTotal()const{return blockCols*blockRows*64;}
        T* getDataPtr(){return data.data();}
        std::vector<T>& getData(){return data;}
        std::unique_ptr<Array2D<T>> reconstructImage();
    
    private:
        uint blockRows;
        uint blockCols;
        std::vector<T> data;
        void array2DToBlockData(const Array2D<T>& image, std::vector<T>& data);
        void blockDataToArray2D(const std::vector<T>& data, Array2D<T>& image);
        void init(uint blockRows, uint blockCols);
};

void passThroughFilter(ImageBlocks<uchar>& input, ImageBlocks<int16_t>& output);
void hardwareDCT(ImageBlocks<uchar>& input, ImageBlocks<int16_t>& output);
void rotate128Beat(std::vector<uint8_t>& data);
void rotate128Beat(std::vector<int16_t>& data);

void softwareDCT(const std::vector<uint8_t>& dataIn, std::vector<int16_t>& dataOut);
