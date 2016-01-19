# MoneyControl.coffee

Captures the historical data of all available symbols from MoneyControl.com website.

It is currently programmed to run for first page only. It takes the suggestion url and parse it to find available symbol. Based on output of various symbol it will fill your model with sc_id, company_name and BSE code. 

Model is [sequelizejs](http://docs.sequelizejs.com/en/latest/) however you can use your own as long as it follows the similar structure. Just burn an image on [Linode](http://j.mp/forcelinode) and run a cron anytime after 8 PM.


