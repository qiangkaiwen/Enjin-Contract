import sys
import random
import BancorFormula
import ActualFormula


def formulaTest(supply,reserve,ratio,amount):
    bancor = BancorFormula.calculatePurchaseReturn(supply,reserve,ratio,amount)
    actual = ActualFormula.calculatePurchaseReturn(supply,reserve,ratio,amount)
    if bancor > actual:
        error = []
        error.append('error occurred on:')
        error.append('supply  = {}'.format(supply ))
        error.append('reserve = {}'.format(reserve))
        error.append('ratio   = {}'.format(ratio  ))
        error.append('amount  = {}'.format(amount ))
        error.append('bancor  = {}'.format(bancor ))
        error.append('actual  = {}'.format(actual ))
        raise BaseException('\n'.join(error))
    return bancor/actual


size = int(sys.argv[1]) if len(sys.argv) > 1 else 0
if size == 0:
    size = input('How many test-cases would you like to execute? ')


worstAccuracy = 1
numOfFailures = 0


for n in xrange(size):
    supply  = random.randrange(2,10**26)
    reserve = random.randrange(1,10**23)
    ratio   = random.randrange(1,99)
    amount  = random.randrange(1,supply)
    try:
        accuracy = formulaTest(supply,reserve,ratio,amount)
        worstAccuracy = min(worstAccuracy,accuracy)
    except Exception,error:
        accuracy = 0
        numOfFailures += 1
    except BaseException,error:
        print error
        break
    print 'Test #{}: accuracy = {:.12f}, worst accuracy = {:.12f}, num of failures = {}'.format(n,accuracy,worstAccuracy,numOfFailures)
