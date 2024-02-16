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


def printSobelPure(div,param):
    param = param / div;
    print(param)

def printSobelShift(div,param,bits):
    param = param / div
    param = param * 2**bits
    print(param)
    
#printSobelShift(sobel3Div,sobel3,12)
printSobelShift(sobel5Div,sobel5,24)
printSobelShift(sobel7Div,sobel7,24)

stencil = np.zeros((7,7))
for y in range(7):
    for x in range(7):
        stencil[y][x] = y*x*5

def applySobel(sobelKernel,sobelDiv,stencil):
    sobelKernel = sobelKernel / sobelDiv
    print(sobelKernel*4096)
    print(stencil)
    mulX = sobelKernel*stencil
    print(mulX*4096)
    sobelKernel = np.transpose(sobelKernel)
    mulY = sobelKernel*stencil
    print(mulY*4096)
    sobel_x = np.sum(mulX)
    sobel_y = np.sum(mulY)
    print(sobel_x*4096)
    print(sobel_y*4096)
    sobel = np.abs(sobel_x+sobel_y)
    print(sobel*4096)
    print(sobel)
    
#applySobel(sobel5,sobel5Div,stencil)


