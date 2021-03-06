import initialization as ini
import datetime
import exchs_data
import matching
import json
import sys
from pprint import pprint
import trading
import time
import os


File = os.path.basename(__file__)


verbose = True
logfile = open('log.txt', 'w')
if not verbose:
    sys.stdout = logfile


def get_best(our_orders, total_balance):
    """
    chooses pair to be traded
    :param our_orders: list of dictionaries with orders for all pairs in form our_orders[pair] = {
                                                                                     'asks': [],
                                                                                     'bids': [],
                                                                                     'required_base_amount': float,
                                                                                     'required_quote_amount': float,
                                                                                     'profit': float
                                                                                 }
    :param total_balance: dictionary with total balance (sum of balances from all exchanges) for each currency
    :return: name of best pair, and dictionary with orders for it
    """
    best_coeff = 0.0
    best_pair = ''
    for pair in our_orders.keys():
        quote_cur = pair.split('_')[1]
        q = our_orders[pair]['profit'] / total_balance[quote_cur]
        if q > best_coeff:
            best_coeff = q
            best_pair = pair
    if best_pair == '':
        return None, None
    else:
        return best_pair, our_orders[best_pair]


def get_json_from_file(file_path):
    """
    extracts JSON from given file
    :param file_path: path to file
    :return: content of file in json format
    """
    try:
        return json.load(open(file_path))
    except FileNotFoundError as e:
        Time = datetime.datetime.utcnow()
        EventType = "Error"
        Function = "get_json_from_file"
        Explanation = "File {} not found".format(file_path)
        EventText = e
        ExceptionType = type(e)
        print("{}|{}|{}|{}|{}|{}|{}".format(Time, EventType, Function, File, Explanation, EventText,
                                            ExceptionType))
    except json.JSONDecodeError as e:
        Time = datetime.datetime.utcnow()
        EventType = "JSONDecodeError"
        Function = "get_json_from_file"
        Explanation = "File {} is not a valid JSON file"
        EventText = e
        ExceptionType = type(e)
        print("{}|{}|{}|{}|{}|{}|{}".format(Time, EventType, Function, File, Explanation, EventText,
                                            ExceptionType))
    except Exception as e:
        Time = datetime.datetime.utcnow()
        EventType = "Error"
        Function = "get_json_from_file"
        Explanation = "Some error occurred while parsing {}".format(file_path)
        EventText = e
        ExceptionType = type(e)
        print("{}|{}|{}|{}|{}|{}|{}".format(Time, EventType, Function, File, Explanation, EventText,
                                            ExceptionType))


#print('\t\tInitialization, {}'.format(datetime.datetime.utcnow()))
botconf = get_json_from_file('bot_config.json')
if botconf is None:
    exit(1)
try:
    pairs = botconf['symbols']
    limit = botconf['limit']
    conffile = get_json_from_file(botconf['config_file'])
    exchsfile = get_json_from_file(botconf['exchs_credentials'])
except KeyError as e:
    Time = datetime.datetime.utcnow()
    EventType = "KeyError"
    Function = "main"
    Explanation = "Some of bot_config.json's required keys are not set"
    EventText = e
    ExceptionType = type(e)
    print("{}|{}|{}|{}|{}|{}|{}".format(Time, EventType, Function, File, Explanation, EventText,
                                        ExceptionType))
    exit(1)
exchs, minvolumes = ini.init(pairs, conffile, exchsfile)
requests = ini.get_urls(pairs, conffile, limit)

currency_list = set()
for pair in pairs:
    for cur in pair.split('_'):
        currency_list.add(cur)


counter = 0

#balances = ini.get_balances(pairs, conffile)
#pprint(balances)


while True:
    counter += 1
    if counter == 100:
        if verbose:
            print('\t\tReinitialization, {}'.format(datetime.datetime.utcnow()))
        exchs, minvolumes = ini.init(pairs, conffile, exchsfile)
        requests = ini.get_urls(pairs, conffile, limit)
        counter = 0
        if len(exchs) <= 1:
            time.sleep(60)
            continue
    try:
        if verbose:
            print('\t\tGetting balances, {}'.format(datetime.datetime.utcnow()))
        balances = ini.get_balances(pairs, conffile)
        # pprint(balances)

        total_balance = {cur: 0 for cur in currency_list}
        for cur in currency_list:
            for exch in balances.keys():
                total_balance[cur] += balances[exch][cur]

        if verbose:
            print('\t\tGetting order books, {}'.format(datetime.datetime.utcnow()))
        order_books = exchs_data.get_order_books(requests, limit, conffile)
        # pprint(order_books['btc_usd'])

        if verbose:
            print('\t\tGenerating arbitrage orders, {}'.format(datetime.datetime.utcnow()))
        our_orders = matching.get_arb_opp(order_books, balances)
        #pprint(our_orders['btc_usd'])

        if verbose:
            print('\t\tChoosing best orders, {}'.format(datetime.datetime.utcnow()))
        best, orders = get_best(our_orders, total_balance)

        if best is None or orders['profit'] < 0.0001:
            if verbose:
                print('\t\tNo good orders. Going to sleep for 30 seconds, {}'.format(datetime.datetime.utcnow()))
            time.sleep(30)
            continue
        # print(best, orders)
        # best = 'btc_usd'
        # orders = {'required_base_amount': 0.01788522, 'required_quote_amount': 132.7579803399024, 'profit': 1.051173937182616, 'buy': {'exmo': [7409, 0.002]}, 'sell': {'cex': [7489, 0.002]}}

        if verbose:
            print('\t\tMaking all orders, {}'.format(datetime.datetime.utcnow()))

        req, res = trading.make_all_orders(best, orders, exchs, conffile)
        Time = datetime.datetime.utcnow()
        EventType = "RequestsForPlacingOrders"
        Function = "main while true"
        Explanation = "Orders generated"
        EventText = req
        ExceptionType = None
        print("{}|{}|{}|{}|{}|{}|{}".format(Time, EventType, Function, File, Explanation, EventText,
                                            ExceptionType))
        Time = datetime.datetime.utcnow()
        EventType = "ResponsesAfterPlacingOrders"
        Function = "main while true"
        Explanation = "Exchanges respond to orders placed"
        EventText = res
        ExceptionType = None
        print("{}|{}|{}|{}|{}|{}|{}".format(Time, EventType, Function, File, Explanation, EventText,
                                            ExceptionType))
        if verbose:
            print('\t\tGoing to sleep for 30 seconds, {}'.format(datetime.datetime.utcnow()))
        time.sleep(30)
    except Exception as e:
        Time = datetime.datetime.utcnow()
        EventType = "Error"
        Function = "main while true"
        Explanation = "Something strange happens"
        EventText = e
        ExceptionType = type(e)
        print("{}|{}|{}|{}|{}|{}|{}".format(Time, EventType, Function, File, Explanation, EventText,
                                            ExceptionType))
