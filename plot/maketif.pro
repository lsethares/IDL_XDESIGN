pro maketif, filename
;create a tif with the content of the current graphic window
;saving in the file "filename". Extension is automatically added.
;
;N.B.:old version had a useless parameter plottif, remove from caller routine if present.

  ;if (!D.name eq 'WIN') then begin
    img=transpose(reverse(transpose(tvrd(true=1))))
    write_tiff,filename+'.tif',img
  ;endif
end
