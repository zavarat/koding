jraphical = require 'jraphical'
KodingError = require '../../error'


module.exports = class JProxyRestriction extends jraphical.Module

  JProxyRule = require './rule'
  {secure, ObjectId}  = require 'bongo'

  @share()

  @set
    softDelete      : no

    sharedMethods   :
      instance      : ['addRule', 'updateRule']
      static        : ['one', 'fetchRestrictionByDomain', 'updateRuleOrders']

    indexes         :
      domainName    : 'unique'

    schema          :
      
      domainName    : String
      ruleList      : [Object]

      createdAt     :
        type        : Date
        default     : -> new Date
      modifiedAt    :
        type        : Date
        default     : -> new Date


  @fetchRestrictionByDomain: (domainName, callback)->
    @one {domainName}, (err, restriction)->
      return callback err if err
      callback err, restriction

  addRule: (params, callback)->
    JProxyRule.one {match:params.match}, (err, rule)=>
      return callback err if err

      unless rule
        rule = new JProxyRule params
        rule.save (err)->
          return callback err if err

      ruleObj = 
        match   : rule.match
        action  : rule.action
        enabled : rule.enabled

      if params.action isnt rule.action
        JProxyRule.update {_id:rule.getId()}, {$set: action: params.action}, (err)->
          return callback err if err

        JProxyRestriction.update 
          _id:@getId()
          "ruleList.match": params.match
        , {$set: "ruleList.$.action": params.action}
        , (err)->
          return callback err if err
      else
        @update {$addToSet: ruleList:ruleObj}, (err)->
          callback err if err

      callback null, rule

  @updateRule: (params, callback)->
    JProxyRestriction.update
      domainName: params.domainName
      "ruleList.match": params.match
    , {$set: "ruleList.$.action": params.action}
    , (err)->
      callback err if err

    JProxyRule.update {match:params.match}, {$set: action: params.action}, (err)->
      callback err if err

    callback null


  @updateRuleOrders: (params, callback)->
    domainName = params.domainName
    newRuleList = params.ruleList
    JProxyRestriction.update {domainName}, {$set: ruleList: newRuleList}, (err)->
      callback err

  @deleteRule: (params, callback)->
    domainName = params.domainName

    JProxyRule.one {match:params.match}, (err, rule)->
      return callback err if err
      return callback (new KodingError("No rule found.")) unless rule

      rule.remove (err)->
        return callback err if err

      ruleObj = 
        match   : rule.match
        action  : rule.action
        enabled : rule.enabled

      JProxyRestriction.update {domainName}, {$pull: ruleList: ruleObj}, (err)->
        return callback err if err

      callback null
    


