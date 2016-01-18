VERSION = 'v1.00';
got = require('got');
moment = require('moment');
_ = require('lodash');
jsdom = require("jsdom");
$ = require('jquery')(jsdom.jsdom().defaultView);
options = {
  tmpDir: "./tmp"
};
Cacheman = require('cacheman');
CachemanFile = require('cacheman-file');
cache = new Cacheman('session', {
  engine: new CachemanFile(options)
});

sha1sum = (input)->
  crypto.createHash('sha1').update(JSON.stringify(input)).digest('hex')
slug = (str) ->
  $slug = ''
  trimmed = _.trim(str)
  $slug = trimmed.replace(/[^a-z0-9-]/gi, '-').replace(/-+/g, '-').replace(/^-|-$/g, '')
  $slug.toLowerCase()

MoneyControl = do ->
  self = false;
  class MoneyControl
    name: 'MoneyControl'
    version: VERSION
    headers: {
      'user-agent': 'Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/46.0.2490.86 Safari/537.36',
      cookie: "PYT_TRACK_SUB=SIGNEDIN; _w18g=1767b027ff7b98c0193762e9dad130ac; __gads=ID=63fd080f7ee94420:T=1442389333:S=ALNI_MbcSckbVdy5bDrtgC8DlyS363Yivw; __utma=1.1617454310.1440488814.1441954354.1444188864.3; __utmz=1.1441954354.2.2.utmcsr=hindi.moneycontrol.com|utmccn=(referral)|utmcmd=referral|utmcct=/; _em_vt=cf93c7671ea4aaace1ed75dabf0c5652b4a87830e2-129471905652b4e9; _ga=GA1.2.1617454310.1440488814; stocks=|Celestial.Labs_CL05~1%7COpto.Circuits_OCI01%7E1%7CAarti.Drugs_AD%7E3%7CHexaware.Tech_A%7E13%7CTata.Motors_TEL%7E2%7C; PHPSESSID=lhjvggkrv67bbm15upf581c0t6; mcusrtrk=91"
    }
    historicalDataUrl: "http://www.moneycontrol.com/stocks/hist_stock_result.php"
    symbolUrl: "http://www.moneycontrol.com/stocks/autosuggest.php"
    _callback: (err, data, callback) ->
#   console.log(err);
#   console.log(data);
      if callback != null
        callback(err, data);
    _get: (url, callback = null, done = null, getParams = {}) ->
      key = slug(url+JSON.stringify(getParams))
      cache.get(key, (err,reply)->
        if reply != null
          console.log "Getting Cache"
          return self._callback(err,reply,callback)
        else
          console.log "Getting Live"
          options = _.merge({}, getParams, self.defaults);
          self.got.get(url,
            options,
            (err, body, res)->
              cache.set(key,body,"1 day")
              self._callback(err, body, callback)
          );
      )
    _delete: (url, callback = null, done = null, getParams = {}) ->
      options = _.merge({}, getParams, self.defaults);
      self.got.delete(url,
        options,
        (err, body, res)->
          self._callback(err, body, callback)
      );
    _post: (url, data = {}, callback = null, done = null, getParams = {}) ->
      options = _.merge({}, data, self.defaults);
      options = _.merge({}, getParams, options);
      self.got.post(url,
        options,
        (err, body, res)->
          self._callback(err, body, callback)
      );
    _patch: (url, options, callback = null, done = null, getParams = {}) ->
      options = _.merge({}, data, self.defaults);
      options = _.merge({}, getParams, options);
      self.got.patch(url,
        self.defaults,
        (err, body, res)->
          self._callback(err, body, callback)
      );
    _historicalData: (sc_id, company_name = "",exchange = "B", callback = null, pno=1, hdn="daily",fdt="2014-12-15",todt="2015-12-15")->
      query = {
        fdt: fdt
        todt: todt
        hdn: hdn
        pno: pno
        ex: exchange
        sc_id: sc_id
        mycomp: company_name
      }
      return self._get(
        self.historicalDataUrl,
        callback,
        null
        {
          query: query
        }
      )

    _getSymbols: (callback = null)->
      self._get(self.symbolUrl,(err,data)->
        symbols = []
        $(data).find('li>a').each((index, row)->
          $row = $(row)
          x = $row.attr("onclick")
          x = x.split("set_val('")[1].split("');")[0].split("','")
          symbols.push({
            company_name : x[0]
            sc_id : x[1]
          })
        )
        if callback!= null
          callback(symbols)
      )
    _crawl: (symbols) ->
      if(_.size(symbols) > 1)
        symbol = symbols.shift()
        exchange = "B"
        self._historicalData(symbol.sc_id, symbol.company_name, exchange, (err,body)->
          console.log("error is "+err)
          historicalData = []
          code = ""
          console.log("Getting Code")
          try
            console.log("Inside Try")
            code = $($(body).find(".PT15 strong")[0]).text().split(":")[1].trim()
          catch

          if code == ""
            console.log "Nothing Found For "+JSON.stringify(symbol)
            return self._crawl(symbols)
          foundDataForDates = []
          console.log("136")
          $(body).find('.tblchart tr').each((index, row)->
            console.log("Inside Find");
            thisRowData = []
            $(row).find('td').each((xindex, td) ->
              console.log("Inside Find TD");
              thisRowData.push($(td).text());
            )
            console.log("142")
            foundDataForDates.push(moment(thisRowData[0], "DD-MM-YYYY").toDate())
            historicalData.push({
              date: moment(thisRowData[0], "DD-MM-YYYY").toDate(),
              open: thisRowData[1],
              high: thisRowData[2],
              low: thisRowData[3],
              close: thisRowData[4],
              volume: thisRowData[5],
              spreadhl: thisRowData[6],
              spreadoc: thisRowData[7],
              code: code,
              exchange: exchange,
              sc_id: symbol.sc_id,
              company_name: symbol.company_name
            });
          );
          console.log("159")
          if(_.size(historicalData) == 0)
            console.log("No Historical Data for "+JSON.stringify(symbol))
            return self._crawl(symbols)
          self.model.destroy({
            where: {
              code: code
              exchange: exchange
              date: {
                $in: foundDataForDates
              }
            }}).then( (data)->
            self.model.bulkCreate(historicalData).then((data)->
              console.log(" TO GO ")
              console.log(_.size(symbols))
              console.log("GOOD SYMBOL "+symbol.sc_id)
              setTimeout(->
                if(_.size(symbols) > 1)
                  self._crawl(symbols)
              ,3000
              )
            )
          )
        )
    constructor: (@model,@formdata) ->
      self = @
      self.got = got
      self.defaults = {
        headers: self.headers
      }
      self._getSymbols(self._crawl)
      @
###
  formdata = {
        frm_dy: "01",
        frm_mth: "01",
        frm_yr: "2014",
        to_dy: "01",
        to_mth: "12",
        to_yr: "2015",
        x: "15",
        y: "13",
        hdn: "daily"
      }
###
module.exports.get = (model, formdata) ->
  new MoneyControl(model,formdata)
