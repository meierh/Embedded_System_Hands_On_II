import sys
import binascii
import numpy as np
import cv2 as cv
from hexdump import hexdump

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
    imageY = 7
    pad = 1
    image = np.zeros((imageY+2*pad,imageX+2*pad),dtype=np.uint8)
    counter = 1
    for y in range(imageY):
        for x in range(imageX):
            image[y+pad,x+pad] = counter
            counter = counter + 1
    threshed = cv.adaptiveThreshold(image, 255, cv.ADAPTIVE_THRESH_MEAN_C, cv.THRESH_BINARY, 3, 0)
    grayImage = cv.cvtColor(image, cv.COLOR_GRAY2BGR)
    print(image)
    #cv.imshow(' ',grayImage)
    #cv.waitKey(0)
    print('Image size: ('+str(imageY+2*pad)+','+str(imageX+2*pad)+')')
    flatImage = image.flatten()
    with open('hexImage.hex', 'w') as f:
        for line in flatImage:
            f.write(f"{hex(line)}\n")
else:
    image = cv.imread(imagePath)
