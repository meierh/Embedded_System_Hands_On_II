import numpy as np
cosBlock = np.zeros((8,8))
for i in range(8):
    for j in range(8):
        cosBlock[i,j] = np.cos(((2*i+1)*j*np.pi)/16)
print(cosBlock)
    
    
