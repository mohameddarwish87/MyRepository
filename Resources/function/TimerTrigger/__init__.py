#***********************************************************************************************************************
#**  Name:                   Timer Trigger Azure Function
#**  Desc:                   This function is created to run every 10 minutes to keep the function app it will be deployed to warm all the times
#**  Auth:                   M Darwish
#**  Date:                   06/12/2021
#**
#**  Change History
#**  --------------
#**  No.     Date            Author              Description
#**  ---     ----------      -----------         ---------------------------------------------------------------
#**  1       06/12/2021      M Darwish           Original Version

import datetime
import logging

import azure.functions as func


def main(mytimer: func.TimerRequest) -> None:
    utc_timestamp = datetime.datetime.utcnow().replace(
        tzinfo=datetime.timezone.utc).isoformat()

    if mytimer.past_due:
        logging.info('The timer is past due!')

    logging.info('Python timer trigger function ran at %s', utc_timestamp)
    x = 0
    x = x + 1
    
