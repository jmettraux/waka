
H.onDocumentReady(function() {

  H.on('[-subject-id]', 'mouseover', function(ev) {

    H.hide('.subject-detail');
    H.unhide('#s' + H.getAtt(ev.target, '^[-subject-id]', '[-subject_id]'));
  });
});

