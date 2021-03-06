function escapeUnderscore,str
  str=strjoin(strsplit(str,'_',/extract),'\_')
  return,strjoin(strsplit(str,'#',/extract),'\#')
end

function process,str,force=force
;  outstr=strsplit(str,'${}')
;  p=strpos(str,"$")
;  if p ne -1 then begin  ;parse mathematical inline formulas
;    ;if keyword_set(force) ne 0 then $
;    ;if fix(np/2)*2 ne np then message,'Something strange with parsing of mathematical inline formula'
;    if p[0] eq 0 then istart=1 else istart=0 ;0 start from math
;    for i=istart,n_elements(outstr)-1,2 do begin
;      outstr[i]=escapeUnderscore(outstr[i])
;    endfor
;    outstr=((p[0] eq 0)?'$':'')+strjoin(outstr,'$')
;  endif else outstr=escapeUnderscore(str)

  p=strAllpos(str,"!",c)
  ;first and last elements of splittedStr are always outside delimiter couples (but they can be empty strings).
  ;splittedStr has always one element more than delimiters
  if c ne 0 then begin  ;parse mathematical inline formulas and other enclosed strings
    delimiters=strExtract(str,p,splitted=splittedStr)  ;string of all delimiters (even number of elements if correctly formed)
    if keyword_set(force) eq 0 then $
    if even(c) ne 1 then message,'Something strange with parsing of text (odd number of delimiters).'
    outStrArr=[escapeUnderscore(splittedStr[0])]
    for i=1,c,2 do begin
      outStrArr=[outStrArr,splittedStr[i],escapeUnderscore(splittedStr[i+1])]
    endfor
    ;outStrArr=[outStrArr,escapeUnderscore(splittedStr[c])]
    exclam=where(outstrArr[1:c-1] eq '',nex)
    if nex ne 0 then outStrArr[1+nex]='!'
    outStr=strJoin(outStrArr)
  endif else outstr=escapeUnderscore(str)
 
  return,outstr
end

pro lr::append,str,noprocess=noprocess,nl=nl
  strl=str
  if keyword_set(noprocess) eq 0 then begin
    for i=0,n_elements(str)-1 do begin
      strl[i]=process(str[i])
    endfor
  endif
  *self.content=[*self.content,strl]
  if keyword_set(nl) then *self.content=[*self.content,newline()]
end

function lr::Init,filename,title=title,author=author,header=header,$
                  footer=footer,toc=toc,maketitle=maketitle,level=level,$
                  nochapter=nochapter
    
    self.written=0
    self.lowestLevel=(n_elements(level) eq 0)?0:level
    self.currentLevel=self.lowestLevel
    ;latex stuff                  
    authorStr=process(n_elements(author) ne 0? '\author{'+author+'}'+newline():"")
    titleStr=process(n_elements(title) ne 0? '\title{'+title+'}'+newline():"")
    maketitle = keyword_set(maketitle) ne 0 ? '\maketitle'+newline():"" 
    documentClass=(self.lowestLevel eq 0)?'\documentclass[twoside]{report}':'\documentclass[titlepage,twoside]{article}'
    ;documentClass='\documentclass[twoside]{report}'
    removeChapter=['\titleformat{\chapter}{\huge\sffamily}{\thechapter}{1em}{}',$
                   '\titlespacing*{\chapter} {0pt}{3.5ex plus 1ex minus .2ex}%',$
                   '{2.3ex plus .2ex}']

    
    standardPreamble=documentClass+newline()+$
    '\usepackage{fullpage}'+newline()+$
    '\usepackage{graphicx}'+newline()+$
    '\usepackage{booktabs}'+newline()+$
    '\usepackage{caption}'+newline()+$
    '\usepackage{mdwlist}'+newline()+$
    '\usepackage{titlesec}'+newline()+$
    '\usepackage{fancyhdr}'+newline()+$
    '\pagestyle{fancy}'+newline()+$
    ;'\renewcommand{\chaptermark}[1]{\markboth{\MakeUppercase{\thechapter.\ #1}}{}}'+newline()
    '\renewcommand{\baselinestretch}{1}'+newline()+$
    '\setlength{\headheight}{15.2pt}'+newline()+$
    '\setcounter{secnumdepth}{4}'+newline()+$
    '\setcounter{tocdepth}{3}'+newline()+$
    '\setlength{\parindent}{0pt}'+newline()+$
    '\setlength{\parskip}{3pt}'+newline()+$
    authorStr+titleStr
    standardHeader='\begin{document}'+newline()+$
    maketitle +$
    (keyword_set(toc) ne 0 ?'\tableofcontents'+newline()+'\newpage'+newline():"")
    
    standardFooter='\end{document}'
    
    self.logfilename=fn(filename)
    self.header= n_elements (header) eq 0? standardHeader :header
    self.preamble= n_elements (preamble) eq 0? standardPreamble :preamble
    self.footer= n_elements (footer) eq 0? standardfooter :footer
    tmp=self.preamble
    self.content=ptr_new(tmp)
    self-> append,[self.user_preamble,self.header] ;these can be replaced before writing on file
    ;but remember to process them in the same way as in append (e.g. removing underscore).
    if keyword_set(nochapter) then *self.content=[*self.content,removechapter]
    return,1
end



pro lr::comment,str
  *self.content=[*self.content,'%'+str]
end

function lr::getproperty,lowestLevel=lowestLevel, currentLevel=currentLevel
  if keyword_set(lowestLevel) then return,self.lowestLevel
  if keyword_set(currentLevel) then return,self.currentLevel
end

function lr::get_lowestLevel
  ;for compatibility
  return,self.lowestLevel
end

pro lr::section,level,title,nonumber=nonumber,clearpage=clearpage,newpage=newpage,shorttitle=shorttitle
;the default is to start a newpage if the level of the section is lower than the current level.
;it will not start a new section if newpage is set to zero. To maintain this behavior, 
;the keyword NEWPAGE must be checked with n_elements instead of keyword_set.

;from: http://www.tex.ac.uk/cgi-bin/texfaq2html?label=runheadtoobig
;the LaTeX sectioning commands therefore take an optional argument:
;
;    \section[short title]{full title}
;
;If the <short title> is present, it is used both for the table of contents and for the page heading. 
;
;However, using the same text for the table of contents as for the running head may also be unsatisfactory: 
;if your chapter titles are seriously long (like those of a Victorian novel), 
;a valid and rational scheme is to have a shortened table of contents entry, 
;and a really terse entry in the running head. 
;In fact, the sectioning commands use ‘mark’ commands to pass information to the page headers. 
;For example, \chapter uses \chaptermark, \section uses \sectionmark, and so on. 
;With this knowledge, one can achieve a three-layer structure for chapters:
;
;    \chapter[middling version]{verbose version}
;    \chaptermark{terse version}
;
;which should supply the needs of every taste.
;
;Chapters, however, have it easy: hardly any book design puts a page header on a chapter start page. In the case of sections, one has typically to take account of the nature of the \*mark commands: the thing that goes in the heading is the first mark on the page (or, failing any mark, the last mark on any previous page). As a result the recipe for sections is more tiresome:
;
;    \section[middling version]{verbose version%
;                  \sectionmark{terse version}}
;    \sectionmark{terse version}
;

;from fancyheader manual: http://www.ctan.org/tex-archive/macros/latex/contrib/fancyhdr/fancyhdr.pdf
;
;
;\leftmark (higher-level) and \rightmark (lower-level) contain the information processed by LATEX
;;The \leftmark contains the Left argument of the Last \markboth on the page, the \rightmark
;contains the Right argument of the fiRst \markboth or the only argument of the fiRst \markright
;on the page. If no marks are present on a page they are “inherited” from the previous page.
;
;ndkov: In practise \markboth, \markright and \markleft are automatically defined by latex 
;while processing sections. fancyheader uses \leftmark and \rightmark to fill the header.
;This allow to change the format (see below), but not the content, to change the content (e.g. refer to
;sections and subsections instead of chapter and sections) \markboth, \markright and \markleft
;can be manually updated putting \markright{title} (or \markleft{title} or \markboth{titleL}{titleR})
;after the chapter/section definition. 
;
;You can influence how chapter, section, and subsection information (only two of them!) is displayed
;by redefining the \chaptermark, \sectionmark, and \subsectionmark commands [There are similar commands 
;for paragraph and subparagraph but they are seldom used.]. You must
;put the redefinition after the first call of \pagestyle{fancy} as this sets up the defaults.
;\renewcommand{\sectionmark}[1]{\markright{\thesection.\ #1}}
;with:
;* the number (say, 2), displayed by the macro \thechapter
;* the name (in English, Chapter), displayed by the macro \chaptername
;* the title, contained in the argument of \chaptermark


;from http://en.wikibooks.org/wiki/LaTeX/Document_Structure
;You can change the depth to which section numbering occurs, so you can turn it off selectively. 
;By default it is set to 2. If you only want parts, chapters, and sections numbered, not subsections 
;or subsubsections etc., you can change the value of the secnumdepth counter using the \setcounter command, 
;giving the depth level from the previous table. For example, if you want to change it to "1":
;
;\setcounter{secnumdepth}{1}
;
;A related counter is tocdepth, which specifies what depth to take the Table of Contents to. 
;It can be reset in exactly the same way as secnumdepth. For example:
;
;\setcounter{tocdepth}{3}
;
;To get an unnumbered section heading which does not go into the Table of Contents, 
;follow the command name with an asterisk before the opening curly brace:
;
;\subsection*{Introduction}
;
;All the divisional commands from \part* to \subparagraph* have this "starred" version 
;which can be used on special occasions for an unnumbered heading when the setting of secnumdepth 
;would normally mean it would be numbered.
;
;If you want the unnumbered section to be in the table of contents anyway, use the \addcontentsline command like this:
;
;\section*{Introduction}
;\addcontentsline{toc}{section}{Introduction}

  maxlenheader=30
  sectionlevels=['chapter','section','subsection','subsubsection','paragraph','subparagraph']
  if n_elements(shorttitle) ne 0 then short='['+shorttitle+']' $
  else short=(strlen(title) le maxlenheader)?'':'['+strmid(title,0,maxlenheader)+']'
  thisSectionLevel=level+self.lowestlevel
  thisSectionToken=sectionLevels[thisSectionLevel]
  
  self->append,['','']
  if keyword_set(clearpage) ne 0 then self->append,'\clearpage'
  if (n_elements(newpage) eq 0) then begin
    if (thisSectionLevel lt self.currentLevel) then self->append,'\newpage'
  endif else begin
    if newpage ne 0 then self->append,'\newpage'
  endelse 
  self->append,'\'+thisSectionToken+(keyword_set(nonumber) ne 0?'*':'')+short+'{'+title+'}'
end

pro lr::list,strArr,nonumber=nonumber
  type=(keyword_set(nonumber) eq 0?'{enumerate*}':'{itemize*}')
  self->append,'\begin'+type
  self->append,'\item '+strarr
  self->append,'\end'+type
end

pro lr::figure,file,caption=caption,parameters=parameters,label=label,float=float
  ;PARAMETERS is a string to be put in the square brackets of includegraphics. 
  parameters=n_elements(parameters) eq 0? "" : parameters
  if (keyword_set(float) ne 0) then begin
    opening=['\begin{figure}','\centering'] 
    closing=['\end{figure}']
    captioncommand='\caption{'
  endif else begin
    opening='\begin{center}'
    closing='\end{center}'
    captioncommand='\captionof{figure}{'
  endelse
  
  self->append,opening
  self->append,'\includegraphics['+parameters+']{'+fn(file,/u)+'}',/noprocess
  if n_elements(caption) ne 0 then self->append,captioncommand+caption+$
      (n_elements(label) eq 0 ?'':'\label{'+label+'}')+'}'
  self->append,closing
end

pro lr::table,tableArray,colFormat,caption=caption,label=label,float=float,autowidth=autowidth,$
    resize=resize,_extra=extra
;possible ways to have automatic width
;\begin{tabular*}{0.75\textwidth}{ | c | c | c | r | }
;\begin{tabular*}{0.75\textwidth}{@{\extracolsep{\fill}} | c | c | c | r | } ;this should look better

;\resizebox{8cm}{!} {
;  \begin{tabular}...
;  \end{tabular}
;}
  if obj_valid(tablearray) then begin   
    if obj_isa(tablearray,'table') then begin 
      if n_elements(caption) ne 0 then tablearray->setproperty,caption=caption
      tablearray->write,self,_extra=extra
      return
    endif else message,'Object type not recognized for table.'
  endif
  
  if n_elements(autowidth) eq 0 then environment=['{tabular}{','{tabular}'] $
    else environment=['{tabular*}{'+strtrim(string(autowidth),2)+'}{@{\extracolsep{\fill}}','{tabular*}']
  if n_elements(resize) eq 0 then resizebox=['',''] $
    else resizebox=['\resizebox{'+strtrim(string(resize),2)+'}{!} {','}']
  if n_elements(caption) ne 0 then ccaption=caption+$
      (n_elements(label) eq 0 ?'':'\label{'+label+'}')+'}' else ccaption=''
  if n_elements(colformat) eq 0 then begin
    colformat=strjoin(replicate('p{3cm}',5))
  endif
  
  if (keyword_set(float) ne 0) then begin
    captioncommand='\caption{'
    opening=['\begin{table}',captioncommand+ccaption,'\centering',resizebox[0]]
    closing=['\end'+environment[1],resizebox[1],'\end{table}']
  endif else begin
    captioncommand='\captionof{table}{'
    opening=[captioncommand+ccaption,'\begin{center}',resizebox[0]]
    closing=['\end'+environment[1],resizebox[1],'\end{center}']
    
  endelse
  ;parameters=n_elements(paramenters) eq 0?"":parameters  
  self->append,opening

  self->append,'\begin'+environment[0]+colFormat+'}'
  self->append,tableArray
  self->append,closing
end

pro lr::Compile,n,noshell=noshell,pdf=pdf,clean=clean
  n= (n_elements(n) eq 0)? 3: n
  if n ne 0 then begin
    if self.written eq 0 then self->write
    print,"Compiling latex, please wait.."
    for i =1,n do begin
        spawn,'cd "'+file_dirname(fn(self.logfilename))+ $
        '" && latex "'+file_basename(fn(self.logfilename))+'"',noshell=noshell
        print,'..'
    endfor
    if n_elements(n) ne 0 then spawn,'cd "'+file_dirname(self.logfilename)+ $
        '" && dvipdfm "'+stripext(self.logfilename)+'.dvi"',noshell=noshell
    if keyword_set(clean) ne 0 then begin
        garbage=stripext(self.logfilename,/full)+['.aux','.dvi','.toc']
        file_delete,garbage, /ALLOW_NONEXISTENT
    endif 
  endif
end


pro lr::Draw
  s=strjoin(*self.content,newline())
  print,s
end

pro lr::Write
  self->append,self.footer
  get_lun,fnum
  openw,fnum,self.logfilename
  printf,fnum,strjoin(*self.content,newline())
  free_lun,fnum
  self.written=1
end

pro lr::Cleanup
  if self.written eq 0 then self->write
  ptr_free,self.content
end

pro lr__define 
struct={lr,$
        logfilename:"",$
        header:"",$,$
        preamble:"",$,$
        user_preamble:"",$
        footer:"",$
        content:ptr_new(),$
        written:0l,$
        lowestLevel:0,$
        currentLevel:0}
end

;pro test_lr,filename
;  obj_new('lr',reportFile,title='Analysis of Influence Function'+$
;  'Measurement on RHW142 Pixel 11',author='Vincenzo Cotroneo',$
;  /maketitle)
;  
;end