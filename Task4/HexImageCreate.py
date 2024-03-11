import sys
import binascii
import numpy as np
import cv2 as cv
from hexdump import hexdump

def split_given_size(a, size):
    return np.split(a, np.arange(size,len(a),size))

imagePath = None
if len(sys.argv) == 1:
    imagePath = None
elif len(sys.argv) == 2:
    imagePath = sys.argv[1]
else:
    raise ValueError("Wrong input")

image = None
if(imagePath is None):
    imageX = 10
    imageY = 3
    pad = 3
    image = np.zeros((imageY+2*pad,imageX+2*pad),dtype=np.uint8)
    counter = 0
    for y in range(imageY):
        for x in range(imageX):
            image[y+pad,x+pad] = 1
            counter = counter + 1
    threshed = cv.adaptiveThreshold(image, 255, cv.ADAPTIVE_THRESH_MEAN_C, cv.THRESH_BINARY, 3, 0)
    grayImage = cv.cvtColor(image, cv.COLOR_GRAY2BGR)
    print(image)
    #cv.imshow(' ',grayImage)
    #cv.waitKey(0)
    print('Image size: ('+str(imageY+2*pad)+','+str(imageX+2*pad)+')')
    flatImage = image.flatten()
    numChunks = int(np.ceil(len(flatImage)/16))
    print("numChunks:",numChunks)
    flatImageChunks = split_given_size(flatImage,16)
    print(flatImageChunks)
            
    with open('SobelFilter/build/hexImage.hex', 'w') as f:
        for line in flatImageChunks:
            for byteInd in range(len(line)):
                f.write(f"{line[byteInd]:02X}")
                #if(byteInd < len(line)-1):
                #f.write(f" ")
            f.write(f"\n")

else:
    image = cv.imread(imagePath)


# RegFile#(UInt#(49), Bit#(128)) img_src <- mkRegFileLoad(`TEST_DIR + "/test_system.hex.in", 0, 437400);
