#include <stdio.h>
#include "SobelFilter.h"

std::unique_ptr<cv::Mat> applySobelFilter(cv::Mat input)
{
    int imageType = input.type();
    if(imageType!=CV_8UC1)
        throw std::invalid_argument("DCT can only handle grayscale images");
    
    correctImageSize(input);
    std::cout<<"Corrected Image size to ("<<input.rows<<","<<input.cols<<")"<<std::endl;
    
    /*
    std::unique_ptr<Array2D<uchar>> arrayInputImage = cvGrayscaleToArray(input);
    std::cout<<"Transfered grayscale image to grayscale 2d-array ("<<arrayInputImage->getRows()<<","<<arrayInputImage->getCols()<<")"<<std::endl;
    
    SobelChunks<uchar> grayScaleBlocks(*arrayInputImage);
    std::cout<<"Transfered Grayscale 2d-array to DCT blocks!"<<std::endl;
    
    SobelChunks<uchar> dctCoeffBlocks;
    passThroughFilter(grayScaleBlocks,dctCoeffBlocks);
    std::cout<<"Passthrough DCT Filter!"<<std::endl;
    
    std::unique_ptr<Array2D<uchar>> grayScaleDctCoeffs = dctCoeffBlocks.reconstructImage();
    std::cout<<"Reconstruct dct to grayscale image!"<<std::endl;
    
    std::unique_ptr<cv::Mat> ouputImage = arrayToCvGrayscale(*grayScaleDctCoeffs);
    std::cout<<"Transfered Grayscale 2d-array to grayscale image"<<std::endl;
    
    return ouputImage;
    */
}

void correctImageSize(cv::Mat& image)
{
    int inputCols = image.cols;
    int inputRows = image.rows;
    
    int paddedInputCols = inputCols+6;
    std::cout<<"paddedInputCols:"<<paddedInputCols<<std::endl;
    int addSizeToNorm = normedColumCount(paddedInputCols);
    std::cout<<"addSizeToNorm:"<<addSizeToNorm<<std::endl;
    int colsToAdd = addSizeToNorm-paddedInputCols;
    std::cout<<"colsToAdd:"<<colsToAdd<<std::endl;

    cv::Mat resizedImage;
    cv::copyMakeBorder(image,resizedImage,3,3,3,3+colsToAdd,cv::BORDER_CONSTANT,0);
    image = resizedImage;
}

int normedColumCount(int cols)
{
    if(cols<=16)
        return 16;
    else
    {
        cols-=16;
        int shiftxCount = cols / 10;
        if(cols%10 != 0)
            shiftxCount++;
        return 16+shiftxCount*10;
    }
}

template<typename T>
Array2D<T>::Array2D(uint cols, uint rows):cols(cols),rows(rows)
{
    data.resize(rows);
    for(uint r=0; r<rows; r++)
        data[r].resize(cols);
}

template<typename T>
T& Array2D<T>::operator()(uint row, uint col)
{
    return data[row][col];
}

template<typename T>
T Array2D<T>::operator()(uint row, uint col) const
{
    return data[row][col];
}

std::unique_ptr<Array2D<uchar>> cvGrayscaleToArray(const cv::Mat image)
{
    if(image.type()!=CV_8UC1)
        throw std::invalid_argument("DCT can only handle grayscale images");
    
    auto arrayPtr = std::make_unique<Array2D<uchar>>(image.cols,image.rows);
    Array2D<uchar>& array = *arrayPtr;
    for(uint row=0; row<image.rows; row++)
    {
        for(uint col=0; col<image.cols; col++)
        {
            array(row,col) = image.at<uchar>(row,col);
        }
    }
    return arrayPtr;
}

std::unique_ptr<cv::Mat> arrayToCvGrayscale(const Array2D<int16_t>& array)
{
    auto imagePtr = std::make_unique<cv::Mat>(array.getRows(),array.getCols(),CV_16U);
    cv::Mat& image = *imagePtr;
    for(uint row=0; row<image.rows; row++)
    {
        for(uint col=0; col<image.cols; col++)
        {
            image.at<ushort>(row,col) = array(row,col);
        }
    }
    return imagePtr;
}

template<typename T>
SobelChunks<T>::SobelChunks(const Array2D<T>& array, uint chunkSize, uint chunkShift)
{
    reset(array,chunkSize,chunkShift);
}

template<typename T>
SobelChunks<T>::SobelChunks(uint rows, uint chunkCols, uint chunkSize, uint chunkShift)
{
    reset(rows,chunkCols,chunkSize);
}

template<typename T>
void SobelChunks<T>::reset(const Array2D<T>& array, uint chunkSize, uint chunkShift)
{
    uint arrayCols = array.getCols();
    arrayCols -= chunkSize;
    uint chunkCols = (arrayCols/chunkShift)+1;
    if(arrayCols%chunkShift!=0)
        throw std::invalid_argument("Invalid column size:"+std::to_string(arrayCols)+"!");
    int rows = array.getRows();
    init(rows,chunkCols,chunkSize,chunkShift);
    array2DToBlockData(array,data);
}

template<typename T>
void SobelChunks<T>::reset(uint rows, uint chunkCols, uint chunkSize, uint chunkShift)
{
    init(rows,chunkCols,chunkSize,chunkShift);
}

template<typename T>
void SobelChunks<T>::init(uint rows, uint chunkCols, uint chunkSize, uint chunkShift)
{
    this->rows = rows;
    this->chunkCols = chunkCols;
    this->chunkSize = chunkSize;
    this->chunkShift = chunkShift;
    data.resize(getTotal());
}

template<typename T>
void SobelChunks<T>::array2DToBlockData(const Array2D<T>& array, uint chunkSize, uint chunkShift, std::vector<T>& data)
{
    /*
    if(data.size()!=array.getCols()*array.getRows())
        throw std::invalid_argument("Size mismatch!");
    */
    
    uint insertIndex=0;
    for(uint chunkColOffset=0; chunkColOffset+chunkSize<array.getCols(); chunkColOffset+=chunkShift)
    {
        for(uint rowInd=0; rowInd<array.getRows(); rowInd++)
        {
            for(uint pxLocCol=0; pxLocCol<chunkSize; pxLocCol++)
            {
                uint col = chunkColOffset+pxLocCol;
                uint row = rowInd;
                T px = array(row,col);
                data[insertIndex] = px;
                insertIndex++;
            }
        }
    }
    
    if(insertIndex!=data.size())
    {
        std::cout<<insertIndex<<"!="<<int(data.size())<<std::endl;
        throw std::invalid_argument("Insertion span mismatch!");
    }
}

template<typename T>
void SobelChunks<T>::blockDataToArray2D(const std::vector<T>& data, Array2D<T>& array, uint chunkSize, uint chunkShift)
{
    /*
    if(data.size()!=array.getCols()*array.getRows())
        throw std::invalid_argument("Size mismatch!");
    */
    
    for(uint extractIndex=0; extractIndex<data.size(); extractIndex++)
    {
        uint chunkNumber = extractIndex/chunkSize;
        uint locChunkInd = extractIndex%chunkSize;
        uint chunkCol = chunkNumber/rows;
        uint chunkRow = chunkNumber%rows;
        uint chunkColOffset = chunkCol*chunkShift;
        uint col = chunkColOffset+locChunkInd;
        uint row = chunkRow;
        T px = data[extractIndex];
        array(row,col) = px;
    }
}

template<typename T>
std::unique_ptr<Array2D<T>> SobelChunks<T>::reconstructImage()
{
    
    auto arrayImage = std::make_unique<Array2D<T>>((chunkCols-1)*chunkShift+chunkSize,rows);
    blockDataToArray2D(data,*arrayImage);
    return arrayImage;
}

void passThroughFilter(std::vector<std::byte> input, std::vector<std::byte> output)
{
    for(int chunkOffset=0; chunkOffset<input.size(); chunkOffset+=16)
    {
        for(int x=3; x<13; x++)
        {
            output.push_back(input[chunkOffset+x]);
        }
    }
}
