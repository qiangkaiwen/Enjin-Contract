import sys
import pymongo
import InputGenerator
import FormulaSolidityPort
import FormulaNativePython


USERNAME      = ''
PASSWORD      = ''
SERVER_NAME   = '127.0.0.1:27017'
DATABASE_NAME = 'test'


MINIMUM_VALUE_SUPPLY  = 100
MAXIMUM_VALUE_SUPPLY  = 10**34
SAMPLES_COUNT_SUPPLY  = 150


MINIMUM_VALUE_RESERVE = 100
MAXIMUM_VALUE_RESERVE = 10**34
SAMPLES_COUNT_RESERVE = 150


MINIMUM_VALUE_RATIO   = 10
MAXIMUM_VALUE_RATIO   = 90
SAMPLES_COUNT_RATIO   = 10


MINIMUM_VALUE_AMOUNT  = 1
MAXIMUM_VALUE_AMOUNT  = 10**34
SAMPLES_COUNT_AMOUNT  = 150


TRANSACTION_SUCCESS  = 0
TRANSACTION_FAILURE  = 1
TRANSACTION_INVALID  = 2
IMPLEMENTATION_ERROR = 3


def Main():
    username      = USERNAME     
    password      = PASSWORD     
    server_name   = SERVER_NAME  
    database_name = DATABASE_NAME
    for arg in sys.argv[1:]:
        username      = arg[len('username='     ):] if arg.startswith('username='     ) else username     
        password      = arg[len('password='     ):] if arg.startswith('password='     ) else password     
        server_name   = arg[len('server_name='  ):] if arg.startswith('server_name='  ) else server_name  
        database_name = arg[len('database_name='):] if arg.startswith('database_name=') else database_name
    if username and password:
        uri = 'mongodb://{}:{}@{}/{}'.format(username,password,server_name,database_name)
    else:
        uri = 'mongodb://{}/{}'.format(server_name,database_name)
    TestAll(pymongo.MongoClient(uri)[database_name]['purchase'])


def TestAll(collection):
    collection.ensure_index([(key,pymongo.ASCENDING) for key in ['supply','reserve','ratio','amount']])
    range_supply  = InputGenerator.UniformDistribution(MINIMUM_VALUE_SUPPLY ,MAXIMUM_VALUE_SUPPLY ,SAMPLES_COUNT_SUPPLY )
    range_reserve = InputGenerator.UniformDistribution(MINIMUM_VALUE_RESERVE,MAXIMUM_VALUE_RESERVE,SAMPLES_COUNT_RESERVE)
    range_ratio   = InputGenerator.UniformDistribution(MINIMUM_VALUE_RATIO  ,MAXIMUM_VALUE_RATIO  ,SAMPLES_COUNT_RATIO  )
    range_amount  = InputGenerator.UniformDistribution(MINIMUM_VALUE_AMOUNT ,MAXIMUM_VALUE_AMOUNT ,SAMPLES_COUNT_AMOUNT )
    for             supply  in range_supply :
        for         reserve in range_reserve:
            for     ratio   in range_ratio  :
                for amount  in range_amount :
                    if True:
                        resultSolidityPort = Run(FormulaSolidityPort,supply,reserve,ratio,amount)
                        resultNativePython = Run(FormulaNativePython,supply,reserve,ratio,amount)
                        if resultNativePython < 0:
                            status = TRANSACTION_INVALID
                            loss = {'absolute':0,'relative':0}
                        elif resultSolidityPort < 0:
                            status = TRANSACTION_FAILURE
                            loss = {'absolute':0,'relative':0}
                        elif resultNativePython < resultSolidityPort:
                            status = IMPLEMENTATION_ERROR
                            loss = {'absolute':0,'relative':0}
                        else: # 0 <= resultSolidityPort <= resultNativePython
                            status = TRANSACTION_SUCCESS
                            loss = {'absolute':float(resultNativePython-resultSolidityPort),'relative':1-float(resultSolidityPort/resultNativePython)}
                        filter = {
                            'supply' :'{}'.format(supply ),
                            'reserve':'{}'.format(reserve),
                            'ratio'  :'{}'.format(ratio  ),
                            'amount' :'{}'.format(amount ),
                        }
                        update = {
                            'resultSolidityPort':'{}'    .format(resultSolidityPort),
                            'resultNativePython':'{:.2f}'.format(resultNativePython),
                            'status':status,
                            'loss'  :loss  ,
                        }
                        document = collection.find_one_and_update(filter,{'$set':update},upsert=True,return_document=pymongo.ReturnDocument.AFTER)
                        print ', '.join('{}: {}'.format(field,document[field]) for field in ['supply','reserve','ratio','amount','resultSolidityPort','resultNativePython','status','loss'])


def Run(module,supply,reserve,ratio,amount):
    try:
        return module.calculatePurchaseReturn(supply,reserve,ratio,amount)
    except Exception:
        return -1


Main()
