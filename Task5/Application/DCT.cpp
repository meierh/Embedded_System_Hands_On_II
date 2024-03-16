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
    hardwareDCT(grayScaleBlocks,dctCoeffBlocks);
    std::cout<<"Hardware DCT Filter!"<<std::endl;
    
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
    auto imagePtr = std::make_unique<cv::Mat>(array.getRows(),array.getCols(),CV_16S);
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
    //std::cout<<"Init ImageBlocks: "<<blockRows<<" "<<blockCols<<std::endl;
    this->blockRows = blockRows;
    this->blockCols = blockCols;
    data.resize(blockCols*blockRows*64);
}

template<typename T>
void ImageBlocks<T>::array2DToBlockData(const Array2D<T>& array, std::vector<T>& data)
{
    //std::cout<<"array2DToBlockData "<<array.getCols()<<" "<<array.getRows()<<" | "<<data.size()<<std::endl;
    if(data.size()!=array.getCols()*array.getRows())
        throw std::invalid_argument("Size mismatch!");
    
    //std::cout<<"Size ("<<blockRows<<","<<blockCols<<")"<<std::endl;
    std::cout<<"array(0,0):"<<int(array(0,0))<<std::endl;
    
    uint insertIndex=0;
    for(uint blockColInd=0; blockColInd<blockCols; blockColInd++)
    {
        for(uint blockRowInd=0; blockRowInd<blockRows; blockRowInd++)
        {
            uint blockOffsetCol = blockColInd*8;
            uint blockOffsetRow = blockRowInd*8;
            
            //std::cout<<"Block ("<<blockRowInd<<","<<blockColInd<<")"<<blockColInd*blockCols+blockRowInd<<" offset: ("<<blockOffsetRow<<","<<blockOffsetCol<<")"<<std::endl;
            
            for(uint pxLocCol=0; pxLocCol<8; pxLocCol++)
            {
                for(uint pxLocRow=0; pxLocRow<8; pxLocRow++)
                {
                    uint col = blockOffsetCol+pxLocCol;
                    uint row = blockOffsetRow+pxLocRow;
                    //std::cout<<"("<<row<<","<<col<<") -> "<<insertIndex<<std::endl;
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
    std::cout<<"data[0]:"<<int(data[0])<<std::endl;
    //throw std::invalid_argument("Temp Stop");
}

template<typename T>
void ImageBlocks<T>::blockDataToArray2D(const std::vector<T>& data, Array2D<T>& array)
{
    if(data.size()!=array.getCols()*array.getRows())
        throw std::invalid_argument("Size mismatch!");
    
    std::cout<<"data[0]:"<<int(data[0])<<std::endl;
    
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
                    uint row = blockOffsetRow+pxLocRow;
                    T px = data[insertIndex];
                    array(row,col) = px;
                    insertIndex++;
                }
            }
        }
    }
    
    if(insertIndex!=data.size())
        throw std::invalid_argument("Insertion span mismatch!");
    
    std::cout<<"array(0,0):"<<int(array(0,0))<<std::endl;
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
        *(outputDataPtr+totalInd) = *(inputDataPtr+totalInd);
    }
    std::cout<<"*(inputDataPtr+0):"<<int(*(inputDataPtr+0))<<std::endl;
    std::cout<<"*(outputDataPtr+0):"<<int(*(outputDataPtr+0))<<std::endl;
}

void hardwareDCT(ImageBlocks<uchar>& input, ImageBlocks<int16_t>& output)
{
    output.reset(input.getBlockRows(),input.getBlockCols());
    
    //Load driver
    int fd_dct = open("/dev/misc_dct", O_RDWR);
    if(fd_dct<0)
    {
	printf("Cannot open dct device\n");
	throw std::logic_error("Failed to open dct device");
    }

    ioctl(fd_dct,IOCTL_DCTWAIT);

    //Set number of blocks
    uint32_t numberBlocks = input.getBlockRows()*input.getBlockCols();
    ioctl(fd_dct,IOCTL_DCTNUMBLOCKS,&numberBlocks);
    	
    //Allocate dma memory
    ioctl(fd_dct,IOCTL_DCTDMAMALLOC);

    //Transfer input image data
    std::vector<uint8_t> inputData = input.getData();
    rotate128Beat(inputData);
    ioctl(fd_dct,IOCTL_DCTINPUTDATA,inputData.data());
    
    //Execute
    ioctl(fd_dct,IOCTL_DCTEXECCMD);
    
    //Wait
    ioctl(fd_dct,IOCTL_DCTWAIT);
   
    //Transfer output image data
    std::vector<int16_t> outputData = output.getData();
    ioctl(fd_dct,IOCTL_DCTOUTPUTDATA,outputData.data());
    rotate128Beat(outputData);

    //Free driver dma
    ioctl(fd_dct,IOCTL_DCTDMAFREE);

    close(fd_dct);
}

void rotate128Beat(std::vector<uint8_t>& data)
{
    if(data.size()%16!=0)
	throw std::logic_error("Invalid data size for beat rotation");
    std::array<uint8_t,16> rotateBeat;
    for(uint beatInd=0; beatInd<data.size(); beatInd+=16)
    {
	for(uint byteInd=0; byteInd<16; byteInd++)
	    rotateBeat[15-byteInd] = data[beatInd+byteInd];
	for(uint byteInd=0; byteInd<16; byteInd++)
	    data[beatInd+byteInd] = rotateBeat[byteInd];
    }
}

void rotate128Beat(std::vector<int16_t>& data)
{
    if(data.size()%8!=0)
	throw std::logic_error("Invalid data size for beat rotation");
    std::array<int16_t,8> rotateBeat;
    for(uint beatInd=0; beatInd<data.size(); beatInd+=8)
    {
	for(uint byteInd=0; byteInd<8; byteInd++)
	    rotateBeat[7-byteInd] = data[beatInd+byteInd];
	for(uint byteInd=0; byteInd<8; byteInd++)
	    data[beatInd+byteInd] = rotateBeat[byteInd];
    }
}
