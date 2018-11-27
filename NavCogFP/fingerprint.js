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

$hulop.fp = (function(){
  try {

    function createStyle(text) {
      return  new ol.style.Style({
        'image' : new ol.style.Circle({
          'fill' : new ol.style.Fill({
            'color' : 'rgba(55, 200, 150, 0.5)'
          }),
          'stroke' : new ol.style.Stroke({
            'width' : 1,
            'color' : 'rgba(55, 200, 150, 0.8)'
          }),
          'radius' : 7
        }),
        'text' : new ol.style.Text({
          'font' : '12px helvetica,sans-serif',
          'text' : text,
          'fill' : new ol.style.Fill({
            'color' : '#000'
          }),
          'stroke' : new ol.style.Stroke({
            'color' : '#fff',
            'width' : 2
          })
        })
      });
    }

    var vectorSource = new ol.source.Vector({
      'projection' : 'EPSG:4326'
    });
    var vectorLayer;
    var styleCache = {
      '*' : createStyle('*')
    };

    function showFingerprints(fps) {
      try {
        if (fps.length == 0) {
          vectorSource.clear();
          return;
        } else if (!vectorLayer) {
          vectorLayer = new ol.layer.Vector({
            'source' : vectorSource,
            'style' : function(f) {
              var text = f.get('name');
              return styleCache[text] || createStyle(text);
            },
            'zIndex' : 105
          });
          $hulop.map.getMap().addLayer(vectorLayer);
        }

        var ids = {};
        fps.forEach(function(fp) {
          if (isNaN(fp.lat + fp.lng)) {
            return;
          }
          var id = fp.lat + ':' + fp.lng + ':' + fp.count;
          ids[id] = true;
          if (!vectorSource.getFeatureById(id)) {
            var f = new ol.Feature({
              'geometry' : new ol.geom.Point(ol.proj.transform([fp.lng, fp.lat], 'EPSG:4326', 'EPSG:3857')),
              'name' : `${fp.count}`
            });
            f.setId(id);
            vectorSource.addFeature(f);
          }
        });
        vectorSource.forEachFeature(function (f) {
          ids[f.getId()] || vectorSource.removeFeature(f);
        });
      } catch(e) {
        console.error(e);
        //alert(e.message);
      }
    }

    return {
      'showFingerprints' : showFingerprints
    };
  } catch(e) {
    //alert(e.message);
  }
})();
