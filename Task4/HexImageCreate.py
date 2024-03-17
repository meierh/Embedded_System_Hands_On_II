import sys
import binascii
import numpy as np
import cv2 as cv
from hexdump import hexdump
import SobelParameters as sobel

np.set_printoptions(linewidth=np.inf)

def split_given_size(a, size):
    return np.split(a, np.arange(size,len(a),size))

def generateImage(chunkX,imageY):
    pad = 3
    image = np.zeros((imageY+2*pad,16+(chunkX-1)*10),dtype=np.uint8)
    counter = 0
    imageX = image.shape[1]-2*pad
    for y in range(imageY):
        for x in range(imageX):
            image[y+pad,x+pad] = counter
            counter = counter + 1
    threshed = cv.adaptiveThreshold(image, 255, cv.ADAPTIVE_THRESH_MEAN_C, cv.THRESH_BINARY, 3, 0)
    grayImage = cv.cvtColor(image, cv.COLOR_GRAY2BGR)
    #print(image)
    #print('Image size: (',image.shape[0],',',image.shape[1],')')
    return image
    
def imageToChunks(image):
    imageY,imageX = np.shape(image)
    chunkX = imageX-16
    chunkX = int(chunkX/10)+1
    #print("chunkX:",chunkX)
    numChunks = imageY*chunkX
    #print("numChunks:",numChunks)
    chunkXOffset=0
    row=0
    chunkList = np.zeros((imageY*chunkX,16),dtype=np.uint8)
    for chunkId in range(np.shape(chunkList)[0]):
        chunkList[chunkId,:] = image[row][chunkXOffset:chunkXOffset+16]
        if row==imageY-1:
            row=0
            chunkXOffset=chunkXOffset+10
        else:
            row=row+1
    #print(chunkList)
    return chunkList

def imageToResultChunks(image):
    imageY,imageX = np.shape(image)
    chunkX = imageX-16
    chunkX = int(chunkX/10)+1
    #print("chunkX:",chunkX)
    numChunks = imageY*chunkX
    #print("numChunks:",numChunks)
    chunkXOffset=0
    row=3
    chunkList = np.zeros(((imageY-6)*chunkX,16),dtype=np.uint8)
    for chunkId in range(np.shape(chunkList)[0]):
        chunkList[chunkId,0:10] = image[row][chunkXOffset+3:chunkXOffset+13]
        if row==imageY-4:
            row=3
            chunkXOffset=chunkXOffset+10
        else:
            row=row+1
    #print(chunkList)
    return chunkList

def chunkListToHexDump(chunkList):
    flatImage = chunkList.flatten()
    numWords = int(np.ceil(len(flatImage)/16))
    #print("numWords:",numWords)
    flatImageChunks = split_given_size(flatImage,16)
    #print(flatImageChunks)
            
    with open('SobelFilter/build/hexImage.hex', 'w') as f:
        for line in flatImageChunks:
            for byteInd in range(len(line)):
                f.write(f"{line[byteInd]:02X}")
            f.write(f"\n")

def applySobelFilter(image,kernel,div):
    results = np.zeros(np.shape(image),dtype=int)
    kernelDiv = kernel/div;
    for y in range(np.shape(image)[0]-6):
        for x in range(np.shape(image)[1]-6):
            stencil = image[y:y+7,x:x+7]
            results[y+3,x+3] = int(sobel.rawSobel(kernelDiv,stencil))
    #print(results)
    return results

img = generateImage(2,6)
print(img)
chunks = imageToChunks(img)
print(chunks)
chunkListToHexDump(chunks)
res = applySobelFilter(img,sobel.sobel3,sobel.sobel3Div)
resChunks = imageToResultChunks(res)
print(resChunks)

stencil = np.zeros((7,7),dtype=np.uint8)
for y in range(7):
    for x in range(7):
        stencil[y][x] = 200-5*x-5*y;
kernelDiv = sobel.sobel5/sobel.sobel5Div
res = int(sobel.rawSobel(kernelDiv,stencil))
print(res)

#print(kernelDiv*2**12)
#print(stencil)
#kernelDiv = sobel.sobel3/sobel.sobel3Div;
#print(kernelDiv)
#res = sobel.rawSobel(kernelDiv,stencil)
#print(res)
