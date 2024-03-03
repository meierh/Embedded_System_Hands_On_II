#include <opencv2/opencv.hpp>
#include <memory>
#include <sys/ioctl.h>
#include <fcntl.h>
#include <unistd.h>
#include "../Driver/ioctl_sobel.h"

std::unique_ptr<cv::Mat> applySobelFilter(cv::Mat input);
int normedColumCount(int cols);
void correctImageSize(cv::Mat& input);

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

std::unique_ptr<Array2D<uchar>> cvGrayscaleToArray(const cv::Mat image);
std::unique_ptr<cv::Mat> arrayToCvGrayscale(const Array2D<int16_t>& array);

template<typename T>
class SobelChunks
{
    public:        
        SobelChunks(){};
        SobelChunks(const Array2D<T>& image, uint chunkSize, uint chunkShift);
        SobelChunks(uint rows, uint chunkCols, uint chunkSize, uint chunkShift);
        void reset(const Array2D<T>& image, uint chunkSize, uint chunkShift);
        void reset(uint rows, uint chunkCols, uint chunkSize, uint chunkShift);
        uint getRows()const{return rows;}
        uint getChunkCols()const{return chunkCols;}
        uint getChunkSize()const{return chunkSize;}
        uint getChunkShift()const{return chunkShift;}
        uint getTotal()const{return rows*chunkCols*chunkSize;}
        T* getDataPtr(){return data.data();}
        std::unique_ptr<Array2D<T>> reconstructImage();
    
    private:
        uint rows;
        uint chunkCols;
        uint chunkSize;
        uint chunkShift;
        std::vector<T> data;
        void array2DToBlockData(const Array2D<T>& image, uint chunkSize, uint chunkShift, std::vector<T>& data);
        void blockDataToArray2D(const std::vector<T>& data, Array2D<T>& image, uint chunkSize, uint chunkShift);
        void init(uint rows, uint chunkCols, uint chunkSize, uint chunkShift);
};

void passThroughFilter(std::vector<std::byte> input, std::vector<std::byte> output);
