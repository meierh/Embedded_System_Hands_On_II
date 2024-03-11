#include <stdio.h>
#include "SobelFilter.h"

std::unique_ptr<cv::Mat> applySobelFilter(cv::Mat input)
{
    int imageType = input.type();
    if(imageType!=CV_8UC1)
        throw std::invalid_argument("DCT can only handle grayscale images");
    
    uint origColums = input.cols;
    
    correctImageSize(input);
    std::cout<<"Corrected Image size to ("<<input.rows<<","<<input.cols<<")"<<std::endl;
    
    std::unique_ptr<Array2D<uchar>> arrayInputImage = cvGrayscaleToArray(input);
    std::cout<<"Transfered grayscale image to grayscale 2d-array ("<<arrayInputImage->getRows()<<","<<arrayInputImage->getCols()<<")"<<std::endl;
    
    SobelChunks<uchar> grayScaleChunks(*arrayInputImage,16,10);
    std::cout<<"Transfered Grayscale 2d-array to Sobel chunks!"<<std::endl;
    
    uchar* chunksPtr = grayScaleChunks.getDataPtr();
    uint pixelNumber = grayScaleChunks.getTotal();
    std::cout<<"pixelNumber:"<<pixelNumber<<std::endl;
    uint chunks = pixelNumber/16;
    std::cout<<"chunks:"<<chunks<<std::endl;
    for(uint chunkId=0; chunkId<chunks; chunkId++)
    {
        for(uint i=0; i<16; i++)
        {
            printf(" %3d",int(*(chunksPtr+chunkId*16+i)));
        }
        printf("\n");
    }
    std::cout<<"---------------------------------------"<<std::endl;
    
    
    SobelChunks<uchar> sobelResultChunks;
    passThroughFilter(grayScaleChunks,sobelResultChunks);
    std::cout<<"Passthrough DCT Filter!"<<std::endl;
    
    chunksPtr = sobelResultChunks.getDataPtr();
    pixelNumber = sobelResultChunks.getTotal();
    std::cout<<"pixelNumber:"<<pixelNumber<<std::endl;
    chunks = pixelNumber/16;
    std::cout<<"chunks:"<<chunks<<std::endl;
    for(uint chunkId=0; chunkId<chunks; chunkId++)
    {
        for(uint i=0; i<16; i++)
        {
            printf(" %3d",int(*(chunksPtr+chunkId*16+i)));
        }
        printf("\n");
    }
    std::cout<<"---------------------------------------"<<std::endl;
    
    std::unique_ptr<Array2D<uchar>> grayScaleSobelImage = sobelResultChunks.reconstructImage();
    std::cout<<"Reconstruct sobel to grayscale image!"<<std::endl;
    
    for(uint y=0; y<grayScaleSobelImage->getRows(); y++)
    {
        for(uint x=0; x<grayScaleSobelImage->getCols(); x++)
        {
            printf(" %3d",(*grayScaleSobelImage)(y,x));
        }
        printf("\n");
    }
    
    std::unique_ptr<cv::Mat> ouputImage = arrayToCvGrayscale(*grayScaleSobelImage,origColums);
    std::cout<<"Transfered Grayscale 2d-array to grayscale image"<<std::endl;
    
    return ouputImage;
}

void correctImageSize(cv::Mat& image)
{
    int inputCols = image.cols;
    int inputRows = image.rows;
    std::cout<<"Got image ("<<inputRows<<","<<inputCols<<")"<<std::endl;
    
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

std::unique_ptr<cv::Mat> arrayToCvGrayscale(const Array2D<uchar>& array)
{
    return arrayToCvGrayscale(array,array.getCols());
}

std::unique_ptr<cv::Mat> arrayToCvGrayscale(const Array2D<uchar>& array, int columns)
{
    if(columns>array.getCols())
        throw std::invalid_argument("Column count must not be larger than array columns");
    auto imagePtr = std::make_unique<cv::Mat>(array.getRows(),columns,CV_16U);
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
    uint rows = array.getRows();
    uint cols = array.getCols();
    cols = cols-chunkSize;
    if(cols%chunkShift!=0 || cols<0)
        throw std::invalid_argument("Invalid column size:"+std::to_string(cols)+"!");
    uint chunkCols = 1 + cols/chunkShift;

    init(rows,chunkCols,chunkSize,chunkShift);
    array2DToChunkData(array,chunkSize,chunkShift,data);
    std::cout<<"Reset done"<<std::endl;
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
void SobelChunks<T>::array2DToChunkData(const Array2D<T>& array, uint chunkSize, uint chunkShift, std::vector<T>& data)
{    
    if(getTotal()!=data.size())
        throw std::invalid_argument("Size mismatch!");
    
    std::cout<<"rows:"<<rows<<std::endl;
    std::cout<<"chunkCols:"<<chunkCols<<std::endl;
    std::cout<<"chunkSize:"<<chunkSize<<std::endl;
    std::cout<<"chunkShift:"<<chunkShift<<std::endl;
    std::cout<<"data.size():"<<data.size()<<std::endl;
    
    uint insertIndex=0;
    for(uint xOffset=0; xOffset+chunkSize<array.getCols()+1; xOffset+=chunkShift)
    {
        //std::cout<<"xOffset:"<<xOffset<<std::endl;
        for(uint row=0; row<array.getRows(); row++)
        {
            //std::cout<<"  row:"<<row<<std::endl;
            for(uint pxInd=0; pxInd<chunkSize; pxInd++)
            {
                //std::cout<<"    pxInd:"<<pxInd<<std::endl;
                std::uint8_t pixel = array(row,xOffset+pxInd);
                data[insertIndex] = pixel;
                insertIndex++;
            }
        }
    }
    std::cout<<"insertIndex:"<<insertIndex<<std::endl;
    
    if(insertIndex!=data.size())
    {
        std::cout<<insertIndex<<"!="<<int(data.size())<<std::endl;
        throw std::invalid_argument("Insertion span mismatch!");
    }
}

template<typename T>
void SobelChunks<T>::chunkDataToArray2D(const std::vector<T>& data, Array2D<T>& array, uint chunkSize, uint chunkShift)
{
    std::cout<<"arrayCol:"<<array.getCols()<<" arrayRow:"<<array.getRows()<<std::endl;
    uint numberChunks = data.size()/chunkSize;
    uint rowIndex = 0;
    uint colIndex = 0;
    std::cout<<"numberChunks:"<<numberChunks<<std::endl;
    for(uint chunkId=0; chunkId<numberChunks; chunkId++)
    {
        for(uint pxInd=0; pxInd<chunkShift; pxInd++)
        {
            uint rdIndex = chunkId*chunkSize + pxInd;
            T dat = data[rdIndex];
            array(rowIndex,colIndex+pxInd) = dat;
        }
        if(rowIndex==array.getRows()-1)
        {
            colIndex+=chunkShift;
            rowIndex=0;
        }
        else
        {
            rowIndex++;
        }
    }
}

template<typename T>
std::unique_ptr<Array2D<T>> SobelChunks<T>::reconstructImage()
{
    uint cols = chunkCols*chunkShift;
    auto arrayImage = std::make_unique<Array2D<T>>(cols,rows);
    chunkDataToArray2D(data,*arrayImage,chunkSize,chunkShift);
    return arrayImage;
}

void passThroughFilter(SobelChunks<uchar> input, SobelChunks<uchar>& output)
{
    uint outputRows = input.getRows()-6;
    output.reset(outputRows,input.getChunkCols(),input.getChunkSize(),input.getChunkShift());
    std::cout<<"size:"<<output.getTotal()<<std::endl;
    uchar* inputDataPtr = input.getDataPtr();
    uchar* outputDataPtr = output.getDataPtr();
    
    uint numberChunks = outputRows*input.getChunkCols();
    
    uint rdIndex = 3*input.getChunkSize();
    uint wrIndex = 0;
    uint countRows = 0;
    for(uint chunkId=0; chunkId<numberChunks; chunkId++)
    {
        for(uint px=0; px<input.getChunkShift(); px++)
        {
            *(outputDataPtr+wrIndex+px) = *(inputDataPtr+rdIndex+px+3);
        }
        wrIndex += input.getChunkSize();
        if(countRows==outputRows-1)
        {
            countRows=0;
            rdIndex += 7*input.getChunkSize();
        }
        else
        {
            countRows++;
            rdIndex += input.getChunkSize();
        }
    }
}
