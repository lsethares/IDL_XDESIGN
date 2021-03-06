function READ_DATAMATRIX, file,skipline=skip,fieldwidth=fieldwidth, $
          nrows=nrows,ncols=n_col,delimiter=delimiter,numline=nl,$
          header=header,type=type,stripblank=strip ;,comment=comment
;da giorgia
; the number of columns is determined by last line read.
;return a matrix of string [ncols,nrows]. NROWS and NCOLS are output parameters.

;added all options. N.B. The code for FIELDWIDTH is missing, but I don't remember
; what the option was for (this also could mean that the option is not so useful).
; It probably was for fixed width data fields? 

;HEADER is a out variable that can be used to return an array of string with the
; content of the first SKIPLINE lines.
;comment (TODO) is a string or an array of strings. A line is ignored if it starts by any
; of the characters in the vector. 

;If STRIPBLANK is set, blank lines are ignored

;2013/02/09 added keyword type. 
;If TYPE is specified, Expression is converted to the specified type. Otherwise data
;are returned as strings.
; See IDL help for a list, in IDL 8.2 is:
; 0   UNDEFINED
; 1   BYTE
; 2   INT
; 3   LONG
; 4   FLOAT
; 5   DOUBLE
; 6   COMPLEX
; 7   STRING
; 8   STRUCT
; 9   DCOMPLEX
; 10  POINTER
; 11  OBJREF
; 12  UINT
; 13  ULONG
; 14  LONG64
; 15  ULONG64

;2013/02/09 found incredible bug, the number of column is determined by the last line
; if it is white the reading is wrong. The bug could be always existing or introduced
; in last week.
; Added STRIPBLANK flag

if n_elements(skip) eq 0 then skip=0
;read file, determine number of columns from the last line
OPENR, unit0, file, /GET_LUN
lines= strarr(1)
i=0L
while ~ EOF(unit0) do begin
  READF,unit0 , lines
  if strlen(strtrim(lines,2)) ne 0 then lastline=lines
  if keyword_set(strip) eq 0 or strlen(strtrim(lines,2)) ne 0 then i=i+1
endwhile
free_lun, unit0

;if n_elements(separator) eq  0 then separator=' ' do not work with tab
nrows=i-skip
if n_elements(delimiter) eq 0 then ncols=n_elements(strsplit(lastline)) $
    else ncols=n_elements(strsplit(lastline,delimiter))
data=strarr(ncols,nrows)
;create matrix and load lines in columns (the first index rotates first,
; it is first to address with * on first index)

OPENR, unit0, file, /GET_LUN
;skip lines
if arg_present(header) then header=[] ; the if is needed to not initialize 
; the variable if it was undefined.
for i=1L,skip do begin
  READF,unit0 , lines
  if arg_present(header) then header=[header,lines]
endfor
i=0L
if n_elements(nl) eq 0 then numline= nrows+1 else numline=nl
while ~ EOF(unit0) and i lt numline do begin
  READF,unit0 , lines
  if strlen(strtrim(lines,2)) ne 0 then begin
    if n_elements(fieldwidth) eq 0 then begin
      if n_elements(delimiter) eq 0 then split=strsplit(lines,/extract) $
      else split=strsplit(lines,/extract,delimiter)
      data[*,i]=split
    endif else begin
      message,"if you want to use fieldwidth option, finish to write the code!"
      for n=0,fix(strlen(lines)/fieldwidth)+1 do begin
      endfor
    endelse 
    i=i+1
  endif else begin
    ;line was white
    if keyword_set(strip) eq 0 then begin
      data[*,i]=lines ;there are no separator, so the scalar element lines is replicated
      i=i+1
    endif
  endelse
endwhile
free_lun, unit0
if n_elements(type) ne 0 then data=fix(data,type=type)
return,data
end
