from math import factorial


MIN_PRECISION = 32
MAX_PRECISION = 127
NUM_OF_PRECISIONS = 128


NUM_OF_COEFS = 34
maxFactorial = factorial(NUM_OF_COEFS)
coefficients = [maxFactorial/factorial(i) for i in range(NUM_OF_COEFS)]


def fixedExpUnsafe(x,precision):
    xi = x
    res = safeMul(coefficients[0],1 << precision)
    for i in range(1,NUM_OF_COEFS-1):
        res = safeAdd(res,safeMul(xi,coefficients[i]))
        xi = safeMul(xi,x) >> precision
    res = safeAdd(res,safeMul(xi,coefficients[-1]))
    return res / coefficients[0]


def safeMul(x,y):
    assert(x * y < (1 << 256))
    return x * y


def safeAdd(x,y):
    assert(x + y < (1 << 256))
    return x + y


def binarySearch(func,args):
    lo = 1
    hi = 1 << 256
    while lo+1 < hi:
        mid = (lo+hi)/2
        try:
            func(mid,args)
            lo = mid
        except Exception,error:
            hi = mid
    try:
        func(hi,args)
        return hi
    except Exception,error:
        func(lo,args)
        return lo


maxExpArray = [0]*NUM_OF_PRECISIONS
for precision in range(NUM_OF_PRECISIONS):
    maxExpArray[precision] = binarySearch(fixedExpUnsafe,precision)


print '    function BancorFormula() {'
for precision in range(NUM_OF_PRECISIONS):
    prefix = '  ' if MIN_PRECISION <= precision <= MAX_PRECISION else '//'
    print '    {}  maxExpArray[{:3d}] = 0x{:x};'.format(prefix,precision,maxExpArray[precision])
print '    }'
