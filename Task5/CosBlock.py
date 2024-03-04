import numpy as np
np.set_printoptions(precision=2)

def computeCosBlock():
    cosBlock = np.zeros((8,8),dtype=np.float128)
    for i in range(8):
        for j in range(8):
            cosBlock[i,j] = np.cos(((2*i+1)*j*np.pi)/16)
    return cosBlock

def computeIntCosBlock(bitwidth):
    cosBlock = computeCosBlock()
    extCosBlock = cosBlock*(2**bitwidth)
    intCosBlock = np.round(extCosBlock)
    error = np.abs(intCosBlock-extCosBlock) / np.min(extCosBlock)*100
    return intCosBlock,error
    
def imageBlock():
    img = np.zeros((8,8),dtype=np.float128)
    for y in range(8):
        for x in range(8):
            if y<4:
                img[y][x] = 255-y*y-3*x*x;
            else:
                img[y][x] = 200-y*y-3*x*x;
    img = np.floor(img)
    return img
    
C = np.array([1/np.sqrt(2),1,1,1,1,1,1,1])

def computeIntCBlock(bitwidth):
    extC = C*(2**bitwidth)
    intC = np.round(extC)
    error = np.abs(intC-extC) / np.min(extC)*100
    return intC,error

def rawDCT(C,img,cosBlock,reduction=1):
    maxVal = max(0,img.all())
    dct = np.zeros((8,8))
    for v in range(8):
        for u in range(8):
            sumDCT = 0
            for x in range(8):
                for y in range(8):
                    maxVal = max(maxVal,cosBlock[y][v])
                    cos2 = cosBlock[x][u]*cosBlock[y][v]
                    maxVal = max(maxVal,cos2)
                    sumDCT += img[y][x]*cos2
                    maxVal = max(maxVal,sumDCT)
            maxVal = max(maxVal,C[u])
            dct[v][u] = C[v]*sumDCT
            maxVal = max(maxVal,dct[v][u])
            dct[v][u] = C[u]*dct[v][u]
            maxVal = max(maxVal,dct[v][u])
            dct[v][u] = 0.25*dct[v][u]
            maxVal = max(maxVal,dct[v][u])
    return dct,maxVal

def matMulDCT(C,img,cosBlock,reduction=1):
    maxVal = max(0,img.all())
    maxVal = max(maxVal,cosBlock.all())
    dct = np.matmul(img,cosBlock)
    maxVal = max(maxVal,dct.all())
    dct = np.matmul(np.transpose(cosBlock),dct)
    maxVal = max(maxVal,dct.all())
    for v in range(8):
        for u in range(8):
            maxVal = max(maxVal,C[u])
            dct[v][u] = C[v]*dct[v][u]
            maxVal = max(maxVal,dct[v][u])
            dct[v][u] = C[u]*dct[v][u]
            maxVal = max(maxVal,dct[v][u])
            dct[v][u] = 0.25*dct[v][u]
            maxVal = max(maxVal,dct[v][u])
    dct = dct / reduction
    return dct,maxVal

def emulDCTIP(img,bitwidth):
    cosBlock = computeIntCosBlock(bitwidth)[0]
    C = computeIntCBlock(bitwidth)[0]
    maxVal = max(0,img.all())
    maxVal = max(maxVal,cosBlock.all())
    dct = np.matmul(img,cosBlock)
    dct = np.floor(dct)
    maxVal = max(maxVal,dct.all())
    #print("DCT1:",dct)
    dct = dct / (2**bitwidth)
    dct = np.floor(dct)
    #print("DCT2:",dct)
    maxVal = max(maxVal,dct.all())
    #print("cosBlock:",cosBlock)
    #print("transpose(cosBlock):",np.transpose(cosBlock))
    dct = np.matmul(np.transpose(cosBlock),dct)
    dct = np.floor(dct)
    #print("DCT3:",dct)
    maxVal = max(maxVal,dct.all())
    dct = dct / (2**bitwidth)
    dct = np.floor(dct)
    #print("DCT4:",dct)
    maxVal = max(maxVal,dct.all())
    for v in range(8):
        for u in range(8):
            maxVal = max(maxVal,C[u].all())
            dct[v][u] = C[v]*dct[v][u]
            dct[v][u] = np.floor(dct[v][u])
            dct[v][u] = dct[v][u] / (2**bitwidth)
    dct = np.floor(dct)
    #print("DCT5:",dct)
    for v in range(8):
        for u in range(8):
            maxVal = max(maxVal,dct[v][u])
            dct[v][u] = C[u]*dct[v][u]
            dct[v][u] = np.floor(dct[v][u])
            dct[v][u] = dct[v][u] / (2**bitwidth)
    dct = np.floor(dct)
    #print("DCT6:",dct)
    for v in range(8):
        for u in range(8):
            maxVal = max(maxVal,dct[v][u])
            dct[v][u] = 0.25*dct[v][u]
            dct[v][u] = np.floor(dct[v][u])
            maxVal = max(maxVal,dct[v][u])
    return dct,maxVal

def computeError(imageGetter,bitwidth):
    img = imageGetter()
    rawDCTBlock = rawDCT(C,img,computeCosBlock())
    intDCTBlock = emulDCTIP(img,bitwidth)
    error = np.divide(np.abs(rawDCTBlock[0]-intDCTBlock[0]),rawDCTBlock[0],out=np.zeros_like(rawDCTBlock[0]), where=np.abs(rawDCTBlock[0])>1e-10)*100
    error = np.max(error)
    return error

def randImage():
    img = np.random.random_integers(0,255,(8,8))
    assert(img.shape==(8,8))
    return img

def linearImage(k=1):
    img = np.zeros((8,8),dtype=np.float128)
    offy = np.random.randint(0,255)
    offx = np.random.randint(0,255)
    coeffy = np.random.randint(-4,4)
    coeffx = np.random.randint(-4,4)
    coeff = np.random.randint(-4,4)
    for y in range(8):
        for x in range(8):
            img[y][x] = coeff*(coeffy*y+offy)*(coeffx*x+offx)
            img[y][x] = img[y][x] % 256
            img[y][x] = np.clip(img[y][x],0,255)
    return img

'''
img  = imageBlock()
print(img)
res = emulDCTIP(img,16)
print("Hardware Solution:",res)
res = rawDCT(C,img,computeCosBlock())
print("Raw Solution:",res)
'''

'''
print(computeIntCosBlock(16))
print(computeIntCBlock(16))
print(computeCosBlock())

img = randImage()
print(img)
rawDCTRes = emulDCTIP(imageBlock(),10)
print(rawDCTRes)

for bitwidth in range(20):
    error = 0
    errorSum = 0
    for k in range(1000):
        img = randImage()
        def imgGetter():
            return img
        oneError = computeError(linearImage,bitwidth)
        error = max(error,oneError)
        errorSum += oneError
    errorSum /= 100
    print("Bitwidth: ",bitwidth,":  ",errorSum,"  ",error)
'''

cosBlock = computeCosBlock()

def visualizeAsUnsiged(image):
    print(type(image))
    for i in range(len(image)):
        for j in range(len(image[i])):
            if(image[i][j]<0):
                image[i][j] = 2**16 + image[i][j]
    return image

def multiBlockImage(num=8): 
    imageX = 8
    imageY = 8
    pad = 0
    counter = 32
    blockList = []
    for blockId in range(num):
        image = np.zeros((imageY+2*pad,imageX+2*pad),dtype=np.uint8)
        for y in range(imageY):
            for x in range(imageX):
                image[y+pad,x+pad] = counter
                counter = counter + 1
        blockList.append(image)
    return blockList

blocks = multiBlockImage()
for i in range(len(blocks)):
    unsignBlock = visualizeAsUnsiged(rawDCT(C,blocks[i],cosBlock)[0])
    print(unsignBlock)
