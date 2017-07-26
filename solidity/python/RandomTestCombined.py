import sys
import random
import BancorFormula


def formulaTest(supply,reserve,ratio,amount):
    newAmount = BancorFormula.calculatePurchaseReturn(supply,reserve,ratio,amount)
    oldAmount = BancorFormula.calculateSaleReturn(supply+newAmount,reserve+amount,ratio,newAmount)
    if oldAmount > amount:
        error = []
        error.append('error occurred on:')
        error.append('supply  = {}'.format(supply ))
        error.append('reserve = {}'.format(reserve))
        error.append('ratio   = {}'.format(ratio  ))
        error.append('amount  = {}'.format(amount ))
        raise BaseException('\n'.join(error))
    return float(oldAmount)/amount


size = int(sys.argv[1]) if len(sys.argv) > 1 else 0
if size == 0:
    size = input('How many test-cases would you like to execute? ')


bestGain = 0
numOfFailures = 0


for n in xrange(size):
    supply  = random.randrange(2,10**26)
    reserve = random.randrange(1,10**23)
    ratio   = random.randrange(1,99)
    amount  = random.randrange(1,supply)
    try:
        gain = formulaTest(supply,reserve,ratio,amount)
        bestGain = max(bestGain,gain)
    except Exception,error:
        gain = 0
        numOfFailures += 1
    except BaseException,error:
        print error
        break
    print 'Test #{}: gain = {:.12f}, best gain = {:.12f}, num of failures = {}'.format(n,gain,bestGain,numOfFailures)
