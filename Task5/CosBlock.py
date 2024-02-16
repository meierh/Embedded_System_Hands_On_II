import numpy as np
np.set_printoptions(precision=2)

bitwidth = 7


cosBlock = np.zeros((8,8),dtype=np.float128)
for i in range(8):
    for j in range(8):
        cosBlock[i,j] = np.cos(((2*i+1)*j*np.pi)/16)
extCosBlock = cosBlock*(2**bitwidth)
intCosBlock = np.round(extCosBlock)
truncCosBlock = intCosBlock / (2**bitwidth)
error = (np.abs(cosBlock-truncCosBlock) / cosBlock)*100;
#print(cosBlock)
#print(truncCosBlock)
#print(error)
print(intCosBlock)

matA = np.zeros((8,8),dtype=np.float128)
matB = np.zeros((8,8),dtype=np.float128)
matB = intCosBlock
for y in range(8):
    for x in range(8):
        matA[y][x] = 255#x*8+y+1
        #matB[y][x] = (y-8)*8+(x-8)#x*8+y+101
        
print(matA)
print(matB)

matC = np.matmul(matA,matB)

print(matC)
