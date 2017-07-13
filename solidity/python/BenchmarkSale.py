from sys     import argv
from decimal import Decimal
from Formula import calculateSaleReturn


def formulaTest(_supply, _reserveBalance, _reserveRatio, _amount):
    fixed = calculateSaleReturn(_supply, _reserveBalance, _reserveRatio, _amount)
    real  = Decimal(_reserveBalance)*(1-(1-Decimal(_amount)/Decimal(_supply))**(100/Decimal(_reserveRatio)))
    if fixed > real:
        error = []
        error.append('error occurred on:')
        error.append('_supply         = {}'.format(_supply))
        error.append('_reserveBalance = {}'.format(_reserveBalance))
        error.append('_reserveRatio   = {}'.format(_reserveRatio))
        error.append('_amount         = {}'.format(_amount))
        error.append('fixed result    = {}'.format(fixed))
        error.append('real  result    = {}'.format(real))
        raise BaseException('\n'.join(error))
    return float(fixed / real)


size = int(argv[1]) if len(argv) > 1 else 0
if size == 0:
    size = input('How many test-cases would you like to execute? ')


bgn = 10**17
end = 10**26
gap = (end-bgn)/size


n = 0
worstAccuracy = 1
numOfFailures = 0
while n < size: # avoid creating a large range in memory
    _supply         = 10**26
    _reserveBalance = 10**23
    _reserveRatio   = 10
    _amount         = bgn+gap*n
    try:
        accuracy = formulaTest(_supply, _reserveBalance, _reserveRatio, _amount)
        worstAccuracy = min(worstAccuracy,accuracy)
    except Exception,error:
        accuracy = 0
        numOfFailures += 1
    except BaseException,error:
        print error
        break
    print 'Test #{}: amount = {:26d}, accuracy = {:.12f}, worst accuracy = {:.12f}, num of failures = {}'.format(n,_amount,accuracy,worstAccuracy,numOfFailures)
    n += 1
