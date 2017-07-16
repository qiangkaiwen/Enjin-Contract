from sys     import argv
from decimal import Decimal
from random  import randrange
from Formula import calculateSaleReturn
from Formula import calculatePurchaseReturn


def formulaTest(supply,reserve,ratio,amount):
    newAmount = calculatePurchaseReturn(supply,reserve,ratio,amount)
    oldAmount = calculateSaleReturn(supply+newAmount,reserve+amount,ratio,newAmount)
    if oldAmount > amount:
        error = []
        error.append('error occurred on:')
        error.append('supply  = {}'.format(supply))
        error.append('reserve = {}'.format(reserve))
        error.append('ratio   = {}'.format(ratio))
        error.append('amount  = {}'.format(amount))
        raise BaseException('\n'.join(error))
    return Decimal(oldAmount)/amount


size = int(argv[1]) if len(argv) > 1 else 0
if size == 0:
    size = input('How many test-cases would you like to execute? ')


n = 0
worstGain = 1
numOfFailures = 0
while n < size: # avoid creating a large range in memory
    supply  = randrange(2,10**26)
    reserve = randrange(1,10**23)
    ratio   = randrange(1,99)
    amount  = randrange(1,supply)
    try:
        gain = formulaTest(supply,reserve,ratio,amount)
        worstGain = min(worstGain,gain)
    except Exception,error:
        gain = 0
        numOfFailures += 1
    except BaseException,error:
        print error
        break
    print 'Test #{}: gain = {:.12f}, worst gain = {:.12f}, num of failures = {}'.format(n,gain,worstGain,numOfFailures)
    n += 1
