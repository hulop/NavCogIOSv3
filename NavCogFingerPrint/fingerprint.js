$hulop.fp = (function(){
  try {
    var vectorSource = new ol.source.Vector({
      projection: 'EPSG:4326'
    });

    function computeFeatureStyle(feature) {
      return  new ol.style.Style({
	image: new ol.style.Circle({
	  fill: new ol.style.Fill({
            color: 'rgba(55, 200, 150, 0.5)'
	  }),
	  stroke: new ol.style.Stroke({
            width: 1,
            color: 'rgba(55, 200, 150, 0.8)'
	  }),
	  radius: 7
	}),
	text: new ol.style.Text({
          font: '12px helvetica,sans-serif',
          text: feature.get('name'),
          fill: new ol.style.Fill({
            color: '#000'
          }),
          stroke: new ol.style.Stroke({
            color: '#fff',
            width: 2
          })
	})
      });
    }
    
    var vectorLayer;
        
    function showFingerprints(fps) {
      try {
	if (!vectorLayer) {
	  vectorLayer = new ol.layer.Vector({
            source: vectorSource,
	    zIndex: 105
	  });
	  $hulop.map.getMap().addLayer(vectorLayer);
	}
	
	var features = fps.map(function(fp) {
	  var point = new ol.geom.Point(ol.proj.transform([fp.lng, fp.lat], 'EPSG:4326', 'EPSG:3857'));
	  var pointFeature = new ol.Feature({
	    geometry: point,
	    name: `${fp.count}`
	  });
	  pointFeature.setStyle(computeFeatureStyle(pointFeature));
	  return pointFeature;
	});
	vectorSource.clear(true);
	vectorSource.addFeatures(features);
      } catch(e) {
	alert(e.message);
      }
    }
    
    return {
      showFingerprints:showFingerprints
    };
  } catch(e) {
    alert(e.message);
  }
})();
