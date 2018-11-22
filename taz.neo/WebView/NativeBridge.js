//
//  NativeBridge.js
//
//  Created by Norbert Thies on 01.08.18.
//  Copyright © 2018 Norbert Thies. All rights reserved.
//

class NativeBridge {

  constructor(bridgeName) {
    this.bridgeName = bridgeName;
    this.callbacks = {};
    this.lastId = 1;
  }

  call( method, func ) {
    var nativeCall = {};
    nativeCall.method = method;
    if ( func != undefined && typeof func == "function" ) {
      nativeCall.callback = this.lastId;
      this.callbacks[this.lastId] = func;
      this.lastId++;
    }
    if ( arguments.length > 2 ) {
      argarray = Array.prototype.slice.call(arguments, 0);
      nativeCall.args = argarray.slice( 2, argarray.length );
    }
    let str = "webkit.messageHandlers." + this.bridgeName + ".postMessage(nativeCall)"
    try { eval(str) }
    catch (error) {
      console.log("Native call: " + error )
    }
    alert(str); 
    if ( nativeCall.callback ) { this.callback(JSON.stringify({callback: this.lastId-1, result: 2})) }
  }
  
  callback( resultData ) {
    var ret = JSON.parse( resultData );
    if ( ret.callback ) {
      var func = this.callbacks[ret.callback];
      if ( func ) {
        delete this.callbacks[ret.callback];
        func.apply( null, [ret.result] );
      }
    }
  } 

}  // class NativeBridge

var Test = new NativeBridge("Test")

Test.f1 = function() { Test.call("testf1", Test.f3) }
Test.f2 = function() { Test.call("testf2", Test.f3) }
Test.f3 = function(arg) { console.log("called back: ", arg) }
