#include <stdio.h>
#include "DCT.h"

std::unique_ptr<cv::Mat> applyDCTPassthrough(cv::Mat input)
{
    int imageType = input.type();
    if(imageType!=CV_8UC1)
        throw std::invalid_argument("DCT can only handle grayscale images");
    
    correctImageSize(input);
    std::cout<<"Corrected Image size to ("<<input.rows<<","<<input.cols<<")"<<std::endl;
    
    std::unique_ptr<Array2D<uchar>> arrayInputImage = cvGrayscaleToArray(input);
    std::cout<<"Transfered grayscale image to grayscale 2d-array ("<<arrayInputImage->getRows()<<","<<arrayInputImage->getCols()<<")"<<std::endl;
    
    ImageBlocks<uchar> grayScaleBlocks(*arrayInputImage);
    std::cout<<"Transfered Grayscale 2d-array to DCT blocks!"<<std::endl;
    
    ImageBlocks<int16_t> dctCoeffBlocks;
    passThroughFilter(grayScaleBlocks,dctCoeffBlocks);
    std::cout<<"Passthrough DCT Filter!"<<std::endl;
    
    std::unique_ptr<Array2D<int16_t>> grayScaleDctCoeffs = dctCoeffBlocks.reconstructImage();
    std::cout<<"Reconstruct dct to grayscale image!"<<std::endl;
    
    std::unique_ptr<cv::Mat> ouputImage = arrayToCvGrayscale(*grayScaleDctCoeffs);
    std::cout<<"Transfered Grayscale 2d-array to grayscale image"<<std::endl;
    
    return ouputImage;
}

void correctImageSize(cv::Mat& image)
{
    int inputRows = image.rows;
    int addToBottom=0;
    if(inputRows%8!=0)
        addToBottom = (((inputRows/8)+1)*8)-inputRows;
    
    int inputCols = image.cols;
    int addToRight=0;
    if(inputCols%8!=0)
        addToRight = (((inputCols/8)+1)*8)-inputCols;
    
    if(addToRight!=0 || addToBottom!=0)
    {
        cv::Mat resizedImage;
        cv::copyMakeBorder(image,resizedImage,0,addToBottom,0,addToRight,cv::BORDER_CONSTANT,0);
        image = resizedImage;
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
ImageBlocks<T>::ImageBlocks(const Array2D<T>& array)
{
    reset(array);
}

template<typename T>
ImageBlocks<T>::ImageBlocks(uint blockRows, uint blockCols)
{
    reset(blockRows,blockCols);
}

template<typename T>
void ImageBlocks<T>::reset(const Array2D<T>& array)
{
    uint arrayCols = array.getCols();
    uint blockCols = arrayCols/8;
    if(arrayCols%8!=0)
        throw std::invalid_argument("Invalid column size!");
    int arrayRows = array.getRows();
    uint blockRows = arrayRows/8;
    if(arrayRows%8!=0)
        throw std::invalid_argument("Invalid row size!");
    init(blockRows,blockCols);
    array2DToBlockData(array,data);
}

template<typename T>
void ImageBlocks<T>::reset(uint blockRows, uint blockCols)
{
    init(blockRows,blockCols);
}

template<typename T>
void ImageBlocks<T>::init(uint blockRows, uint blockCols)
{
    this->blockRows = blockRows;
    this->blockCols = blockCols;
    data.resize(blockCols*blockRows*64);
}

template<typename T>
void ImageBlocks<T>::array2DToBlockData(const Array2D<T>& array, std::vector<T>& data)
{
    if(data.size()!=array.getCols()*array.getRows())
        throw std::invalid_argument("Size mismatch!");
    
    uint insertIndex=0;
    for(uint blockColInd=0; blockColInd<blockCols; blockColInd++)
    {
        for(uint blockRowInd=0; blockRowInd<blockRows; blockRowInd++)
        {
            uint blockOffsetCol = blockColInd*8;
            uint blockOffsetRow = blockRowInd*8;
            for(uint pxLocCol=0; pxLocCol<8; pxLocCol++)
            {
                for(uint pxLocRow=0; pxLocRow<8; pxLocRow++)
                {
                    uint col = blockOffsetCol+pxLocCol;
                    uint row = blockOffsetCol+pxLocCol;
                    T px = array(row,col);
                    data[insertIndex] = px;
                    insertIndex++;
                }
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
void ImageBlocks<T>::blockDataToArray2D(const std::vector<T>& data, Array2D<T>& array)
{
    if(data.size()!=array.getCols()*array.getRows())
        throw std::invalid_argument("Size mismatch!");
    
    uint insertIndex=0;
    for(uint blockColInd=0; blockColInd<blockCols; blockColInd++)
    {
        for(uint blockRowInd=0; blockRowInd<blockRows; blockRowInd++)
        {
            uint blockOffsetCol = blockColInd*8;
            uint blockOffsetRow = blockRowInd*8;
            for(uint pxLocCol=0; pxLocCol<8; pxLocCol++)
            {
                for(uint pxLocRow=0; pxLocRow<8; pxLocRow++)
                {
                    uint col = blockOffsetCol+pxLocCol;
                    uint row = blockOffsetCol+pxLocCol;
                    T px = data[insertIndex];
                    array(row,col) = px;
                    insertIndex++;
                }
            }
        }
    }
    
    if(insertIndex!=data.size())
        throw std::invalid_argument("Insertion span mismatch!");
}

template<typename T>
std::unique_ptr<Array2D<T>> ImageBlocks<T>::reconstructImage()
{
    auto arrayImage = std::make_unique<Array2D<T>>(blockCols*8,blockRows*8);
    blockDataToArray2D(data,*arrayImage);
    return arrayImage;
}

void passThroughFilter(ImageBlocks<uchar>& input, ImageBlocks<int16_t>& output)
{
    output.reset(input.getBlockRows(),input.getBlockCols());
    uchar* inputDataPtr = input.getDataPtr();
    int16_t* outputDataPtr = output.getDataPtr();
    for(uint totalInd=0; totalInd<input.getTotal(); totalInd++)
    {
        *(inputDataPtr+totalInd) = *(outputDataPtr+totalInd);
    }
}

void hardwareDCT(ImageBlocks<uchar>& input, ImageBlocks<int16_t>& output)
{
    output.reset(input.getBlockRows(),input.getBlockCols());
    
    int fd_dct = open("/dev/misc_dct", O_RDWR);
	if(fd_dct<0)
	{
		printf("Cannot open dct device\n");
		throw std::logic_error("Failed to open dct device");
	}
	
	//Set number of blocks
    uint64_t numberBlocks = input.getBlockRows()*input.getBlockCols();
	ioctl(fd_dct,IOCTL_DCTNUMBLOCKS,&numberBlocks);
	
	//Set input image size
    uint64_t imageInputSize = input.getTotal();
	ioctl(fd_dct,IOCTL_DCTINPUTSIZE,&imageInputSize);
    
    //Set output image size
    uint64_t imageOutputSize = input.getTotal()*2;
	ioctl(fd_dct,IOCTL_DCTOUTPUTSIZE,&imageOutputSize);
    
    //Allocate dma memory
	ioctl(fd_dct,IOCTL_DCTDMAMALLOC);

    //Transfer input image data
    uchar* inputDataPtr = input.getDataPtr();
	ioctl(fd_dct,IOCTL_DCTINPUTDATA,(uint8_t*)inputDataPtr);
    
    //Execute
	ioctl(fd_dct,IOCTL_DCTEXECCMD);
    
    // Wait for status
    uint64_t status;
	ioctl(fd_dct,IOCTL_DCTSTATUS,&status);
    
    int16_t* outputDataPtr = output.getDataPtr();
	ioctl(fd_dct,IOCTL_DCTOUTPUTDATA,(uint8_t*)outputDataPtr);

	ioctl(fd_dct,IOCTL_DCTDMAFREE);
    
    close(fd_dct);
}
