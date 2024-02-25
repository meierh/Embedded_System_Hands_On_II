import sys
import binascii
import numpy as np
import cv2 as cv

np.set_printoptions(precision=2)

sobel3Div = 8;
sobel3 = np.array([[0,0,0,0,0,0,0],
                   [0,0,0,0,0,0,0],
                   [0,0,1,0,-1,0,0],
                   [0,0,2,0,-2,0,0],
                   [0,0,1,0,-1,0,0],
                   [0,0,0,0,0,0,0],
                   [0,0,0,0,0,0,0]],dtype=np.float128)

sobel5Div = 96;
sobel5 = np.array([[0,0, 0,0,  0, 0, 0],
                   [0,1, 2,0, -2,-1, 0],
                   [0,4, 8,0, -8, 4, 0],
                   [0,6,12,0,-12,-6, 0],
                   [0,4, 8,0, -8,-4, 0],
                   [0,1, 2,0, -2,-1, 0],
                   [0,0, 0,0,  0, 0, 0]],dtype=np.float128)

sobel7Div = 1280;
sobel7 = np.array([[ 1, 4,  5,0,  -5, -4, -1],
                   [ 6,24, 30,0, -30,-24, -6],
                   [15,60, 75,0, -75, 60, 15],
                   [20,80,100,0,-100,-80,-20],
                   [15,60, 75,0, -75, 60, 15],
                   [ 6,24, 30,0, -30,-24, -6],
                   [ 1, 4,  5,0,  -5, -4, -1]],dtype=np.float128)

def computeIntKernel(kernel,bitwidth):
    extKernel = kernel*(2**bitwidth)
    intKernel = np.round(extKernel)
    error = np.abs(intKernel-extKernel) / np.min(extKernel)*100
    return extKernel,error

def imageBlock():
    img = np.zeros((7,7),dtype=np.float128)
    for y in range(7):
        for x in range(7):
            if y<4:
                img[y][x] = 255-y*y-3*x*x;
            else:
                img[y][x] = 200-y*y-3*x*x;
    img = np.floor(img)
    return img

def randImage():
    img = np.random.random_integers(0,255,(7,7))
    assert(img.shape==(7,7))
    return img

def rawSobel(kernel,stencil):
    mulSobelX = np.zeros((7,7),dtype=np.float128)
    mulSobelY = np.zeros((7,7),dtype=np.float128)
    for y in range(7):
        for x in range(7):
            mulSobelX[y][x] = stencil[y][x]*kernel[y][x]
            mulSobelY[y][x] = stencil[y][x]*kernel[x][y]
    sumSobelX = np.zeros((7),dtype=np.float128)
    sumSobelY = np.zeros((7),dtype=np.float128)
    for y in range(7):
        for x in range(7):
            sumSobelX[y] = sumSobelX[y] + mulSobelX[y][x]
            sumSobelY[y] = sumSobelY[y] + mulSobelY[y][x]
    sobelX = np.sum(sumSobelX)
    sobelY = np.sum(sumSobelY)
    sobel = np.abs(sobelX+sobelY)
    return sobel

def emulSobel(kernel,stencil,bitwidth):
    kernel = computeIntKernel(kernel,bitwidth)
    mulSobelX = np.zeros((7,7),dtype=np.float128)
    mulSobelY = np.zeros((7,7),dtype=np.float128)
    for y in range(7):
        for x in range(7):
            mulSobelX[y][x] = stencil[y][x]*kernel[y][x]
            mulSobelY[y][x] = stencil[y][x]*kernel[x][y]
    mulSobelX = np.floor(mulSobelX)
    mulSobelY = np.floor(mulSobelY)
    sumSobelX = np.zeros((7),dtype=np.float128)
    sumSobelY = np.zeros((7),dtype=np.float128)
    for y in range(7):
        for x in range(7):
            sumSobelX[y] = sumSobelX[y] + mulSobelX[y][x]
            sumSobelY[y] = sumSobelY[y] + mulSobelY[y][x]
    sumSobelX = np.floor(sumSobelX)
    sumSobelY = np.floor(sumSobelY)
    sobelX = np.sum(sumSobelX)
    sobelY = np.sum(sumSobelY)
    sobelX = np.floor(sobelX)
    sobelY = np.floor(sobelY)
    sobel = np.abs(sobelX+sobelY)
    sobel = np.floor(sobel)
    return sobel

def computeError(img,kernel,bitwidth):
    rawSobelBlock = rawSobel(kernel,img)
    intSobelBlock = emulSobel(kernel,img,bitwidth)
    error = np.divide(np.abs(rawSobelBlock-intSobelBlock),rawSobelBlock,out=np.zeros_like(rawSobelBlock), where=np.abs(rawSobelBlock)>1e-10)*100
    error = np.max(error)
    return error

for bitwidth in range(20):
    error = 0
    errorSum = 0
    for k in range(1000):
        img = randImage()
        def imgGetter():
            return img
        oneError = computeError(img,sobel3/sobel3Div,bitwidth)
        error = max(error,oneError)
        errorSum += oneError
    errorSum /= 100
    print("Bitwidth: ",bitwidth,":  ",errorSum,"  ",error)

