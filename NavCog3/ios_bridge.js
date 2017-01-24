/*******************************************************************************
 * Copyright (c) 2014, 2016  IBM Corporation, Carnegie Mellon University and others
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *******************************************************************************/

(function() {
  window.$IOS = {
 
    'getFrame' : function() {
      var frame = document.getElementById('__native__call__iframe__');
      if (!frame) {
        frame = document.createElement('iframe');
        frame.id = '__native__call__iframe__';
        frame.style.position = 'absolute';
        frame.style.left = '-1px';
        frame.style.top = '-1px';
        frame.style.width = '1px';
        frame.style.height = '1px';
        frame.border = "0";
        document.body.appendChild(frame);
      }
      return frame;
    },
    'callNative' : function(component, func, params) {
      this.queue.push({component:component,func:func,params:params});
      if (!this.interval) {
        this.interval = setInterval(function() {
          $IOS.processNext();
        }, 0);
      }
    },
    'callNativeWithCallback': function(component, func, params, callback) {
      var id = (new Date()).getTime();
      this.callbacks[id] = callback;
      params.callback = "window.$IOS.callbacks["+id+"]";
      this.callNative(component, func, params);
    },
    'callbacks' : {},
    'queue' : [],
    'readyForNext' : true,
    'processNext' : function() {
      if (!$IOS.readyForNext) {
        return;
      }
      $IOS.readyForNext = false;
      var obj = $IOS.queue.shift();
 console.log(obj);
      if ($IOS.queue.length == 0) {
        clearInterval($IOS.interval);
        $IOS.interval = null;
      }
      var component = obj.component;
      var func = obj.func;
      var params = obj.params;
      
      var frame = this.getFrame();
      var url = 'native://' + component + '/' + func + '?';
      if (params) {
        var first = true;
        for ( var key in params) {
          if (!first) {
            url += '&';
          }
          url += key + '=' + encodeURIComponent(params[key]);
          first = false;
        }
        url += '&_dummy_=' + new Date().getTime();
      }
      frame.src = url;
    }
  };
  
  
  window.ios_mobile_bridge = {
    speak: function(text, flush) {
      $IOS.callNative('SpeechSynthesizer', 'speak', {'text':text, 'flush':flush});
    },
    setCallback: function(name) {
      $IOS.callNative('Property', 'callback', {'value':name});
    },
    isSpeaking: function(name) {
      $IOS.callNative('SpeechSynthesizer', 'isSpeaking', {callbackname:name});
    },
    startRecognizer: function(name) {
      $IOS.callNative('STT', 'startRecognizer', {callbackname:name});
    },
    mapCenter: function(lat, lng, floor, sync) {
      $IOS.callNative('Property', 'mapCenter', {'lat':lat,'lng':lng,'floor':floor,'sync':sync});
    },
    logText: function(text) {
      $IOS.callNative('System', 'log', {'text':text});
    },
    vibrate: function() {
      $IOS.callNative('AudioServices', 'vibrate', {});
    },
    mIsSpeaking: false
  }

  if (window.$hulop && window.$hulop.mobile_ready) {
    window.$hulop.mobile_ready(ios_mobile_bridge);
  }
  document.body.style.webkitTouchCallout='none';
  document.body.style.KhtmlUserSelect='none';
  document.body.style.webkitUserSelect='none';
  return "SUCCESS";
})();

