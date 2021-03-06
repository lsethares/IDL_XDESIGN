;2012/5/16 copy before adding readers
; TODO: accept a string or a object in report, if string, use it as the name of the latex file to be created,
;       if object, append (as now).  
; TODO: compile the pdf only if latex did not give errors
; TODO: modify graphs to put histogram on side of profile plots
; TODO: psdwindow is set here to hanning and also the matrix is created, but it is not an input value.
;   Also not sure that the window_m is useful.
; TODO: the data file format is managed by means of the _extra keyword
;   
;v2: added groups for averagePSD
;
;
;+
; NAME:
; MULTIPSD
;
; PURPOSE:
; This procedure calculate all the parameters and data needed for a report 
; from different Dektat measurement data files.
; Create a latex report according to the input parameters and generate all the images.
; outfolder is the folder that contain the imgdir (<outname>_img).
; if a report object is not passed in <report>, create it in outfolder with name <outname>_report, 
; otherwise append.
; outname is used in the plot titles and for the names and folder of the created images.
;
; CATEGORY:
; Dektat
;
; CALLING SEQUENCE:
; MULTIPSD, Filelist
;
; INPUTS:
;    Filelist: array of strings with the path of the datafiles to process.
;
; OPTIONAL INPUTS:
;    ROI_UM: 2-elements array indicating (in um) the start and end of the region of profile to be used
;      for calculating the output. If not provided, the whole data are used.
;    NBINS:
;    SECTIONLEVEL
;    OUTNAME:string used for generation of name and labels. 
;    REPORT
;    AUTHOR
;    TITLE
;    OUTFOLDER
;    LABELS
;    NONUM
;    TEXT
;    INCLUDESECTIONS
;    BASEINDEX
;    ALLCOUPLES
;    XINDEX
;    XOFFSET
;    GROUPS: array of integers that describes how to divide the list of files into groups (e.g.: [2,3,1] 
;      to create three groups of respectively 2, 3 and 1 elements). 
;    GROUPNAMES
; 
; KEYWORD PARAMETERS:
; KEY1: Document keyword parameters like this. Note that the keyword
;   is shown in ALL CAPS!
;
; KEY2: Yet another keyword. Try to use the active, present tense
;   when describing your keywords.  For example, if this keyword
;   is just a set or unset flag, say something like:
;   "Set this keyword to use foobar subfloatation. The default
;    is foobar superfloatation."
;
; OUTPUTS:
; Describe any outputs here.  For example, "This function returns the
; foobar superflimpt version of the input array."  This is where you
; should also document the return value for functions.
;
; OPTIONAL OUTPUTS:
; Describe optional outputs here.  If the routine doesn't have any, 
; just delete this section.
;
; COMMON BLOCKS:
; BLOCK1: Describe any common blocks here. If there are no COMMON
;   blocks, just delete this entry.
;
; SIDE EFFECTS:
; Describe "side effects" here.  There aren't any?  Well, just delete
; this entry.
;
; RESTRICTIONS:
; Describe any "restrictions" here.  Delete this section if there are
; no important restrictions.
;
; PROCEDURE:
; You can describe the foobar superfloatation method being used here.
; You might not need this section for your routine.
;
; EXAMPLE:
; Please provide a simple example here. An example from the
; DIALOG_PICKFILE documentation is shown below. Please try to
; include examples that do not rely on variables or data files
; that are not defined in the example code. Your example should
; execute properly if typed in at the IDL command line with no
; other preparation. 
;
;       Create a DIALOG_PICKFILE dialog that lets users select only
;       files with the extension `pro'. Use the `Select File to Read'
;       title and store the name of the selected file in the variable
;       file. Enter:
;
;       file = DIALOG_PICKFILE(/READ, FILTER = '*.pro') 
;
; MODIFICATION HISTORY:
;   Written by: Vincenzo Cotroneo, 25 February 2011.
;   Harvard-Smithsonian Center for Astrophysics
;   60, Garden street, Cambridge, MA, USA, 02138
;   vcotroneo@cfa.harvard.edu
;   
;-
;


; 
;values for includesections
    ;0 general information
    ;1 raw data and scan settings
    ;2 leveling and stats
    ;3 psd average with fit - also for groups
    ;4 differences between raw profiles and stats   
    ;5 differences between leveled profiles and stats
    ;6 psd analysis and fit  

pro multipsd,filelist,roi_um=roi_um,nbins=nbins,sectionlevel=sectionlevel,outname=outname,$
  report=report,author=author,title=title,outfolder=outfolder,labels=labels,nonum=nonum,text=text,$
  includeSections=includeSections,baseIndex=baseIndex,allcouples=allcouples,xindex=xIndex,xoffset=xoffset,$
  groups=groups,groupnames=groupnames

;--------------- 1 - initialiation of settings ----------------------------
maxAllcouplesDiff=3 ;if number of files is larger than this number, 
;plot only the difference with respect to a single file, otherwise plot all couples

if n_elements(groups) ne 0 and ~in(3,includeSections) then warning,'Groups are indicated, but the plotting of average is not set. The average PSD will not be calculated.'
;if n_elements(nbins) eq 0 then begin
;  warning,'nbins eq 0, default value of 100 assumed.'
;  nbins=100
;endif

print,'**'+outname+'**'
nfiles=n_elements(filelist)
;create a matrix of settings for roi_um, this will be used internally by the program.
if n_elements(roi_um) ne 0 then begin
  if n_elements(roi_um) eq 2*nfiles then roi_um_m=reform(roi_um,2,nfiles) $
  else if n_elements(roi_um) eq 2 then roi_um_m=rebin(roi_um,2,nfiles) else message,$
    'wrong number of elements for roi, roi= ,+string(roi_um)
  roi_um_m=float(roi_um_m)
endif
;same with psdwindow, create window_m
if n_elements(psdwindow) eq 0 then window_m=strarr(nfiles) else window_m=replicate(psdwindow,1,nfiles)

;set folder dependant parameters.
ps=1 ;this can be set to 0 for debug to generate plots on screen. 
levelPartial=1 ;this defines the degree of polynomial to subtract for the partial stats (comparison with Dektat=1)
fCut=4. ;fractional cut in freq range for fitof PSD. e.g. if it is 4 use from 4/L to 4*step.
;N.B.: this is used in this routine and is passed in extractpsd. The two routines must be kept synchronized.
if n_elements(outname) ne 0 then titlestring=outname+': ' else titlestring=''
img_dir=outfolder+path_sep()+outname+'_img'
if file_test(img_dir,/directory) eq 0 then file_mkdir,img_dir ;automatically create also outfolder

;graphics settings
set_plot_default
setStandardDisplay
if ps ne 0 then begin
  thstore=[!P.thick,!X.thick,!y.thick,!P.charthick]
  !P.thick=2
  !X.thick=2
  !y.thick=2
  !P.charthick=2
endif
colors=plotcolors(nfiles)

if n_elements(xoffset) eq 0 then xoffset=0
if n_elements(xoffset) eq 1 then xoffset=replicate(xoffset,nfiles) else $
  if n_elements(xoffset) ne nfiles then message,'invalid number of elements for xoffset='+string(n_elements(xoffset))
xoffset=float(xoffset)
  
get_lun,psfn
openw,psfn,img_dir+path_sep()+outname+'_verifyStats.txt'
printf,psfn,'Profile stats after the removal of the first ',levelPartial+1,' components,'
printf,psfn,'for comparison with the measuring software values.'
maxlennames=max(map('strlen',filelist))
printf,psfn
printf,psfn,'Filename','rms','Ra','PV',format='(a'+$
      ',T'+strtrim(string(maxlennames+3),2)+',TR7,a,TR8,a,TR8,a)'

;--------------- 2 - calculation and plot of results ----------------------------
for i=0,nfiles-1 do begin
  print,'---',i,': ',filelist[i],'---'
  extractpsd,filelist[i],roi_um=roi_um_m[*,i],nbins=nins,$ ;img_dir='test',wplot=[1,2,3],$
    x_roi_out=x_roi,y_roi_out=y_roi,freq=f,psd=psd,zlocations=zlocations,zhist=zhist,$
    xraw=x,yraw=y,level_coeff=level,scan_pars=scan_pars,fitpsd=fitpars,$
    normpars=normpars,fourierwindow=window_m[i],xoffset=xoffset[i],$
    levelPartial=levelPartial,partialStats=partialStats,fCut=fCut
  
  if i eq 0 then begin 
    x_roi_m=x_roi
    y_roi_m=y_roi
    x_m=x
    y_m=y
    f_m=f
    level_m=level
    psd_m=psd
    scan_pars_m=scan_pars
    normpars_m=normpars
    fitpars_m=fitpars
    partialStats_m=partialStats
  endif else begin
    x_roi_m=concatenate(x_roi_m,x_roi,2)
    y_roi_m=concatenate(y_roi_m,y_roi,2)
    x_m=concatenate(x_m,x,2)
    y_m=concatenate(y_m,y,2)
    f_m=concatenate(f_m,f,2)
    level_m=concatenate(level_m,level,2)
    psd_m=concatenate(psd_m,psd,2)
    scan_pars_m=concatenate(scan_pars_m,scan_pars,2)
    fitpars_m=concatenate(fitpars_m,fitpars,2)
    normpars_m=concatenate(normpars_m,normpars,2)
    partialStats_m=concatenate(partialStats_m,partialStats,2)
  endelse
  printf,psfn,filelist[i],partialstats[0],partialstats[1],partialstats[2],format='(a'+$
      ',T'+strtrim(string(maxlennames+3),2)+',f10.1,TR2,f10.1,TR2,f10.1)'
endfor
free_lun,psfn

if n_elements(labels) eq nfiles then legstr=labels $
  else begin
  if n_elements(labels) ne 0 then print,'MULTIPSD WARNING: nr of labels ('+string(n_elements(labels))+$
      ') does not correspond to the number of files ('+string(nfiles)+'), labels will be generated by the program.'
  legStr=stripext(filelist)
endelse 

;create raw profile plot and data
if ps ne 0 then begin
  file_mkdir,img_dir
  SET_PLOT, 'PS'
  DEVICE, filename=img_dir+path_sep()+outname+'_rawdata.eps', /COLOR,/encapsulated  
endif else window,0
plot,[0],[0],xtitle='x (mm)',ytitle='y (A)',background=255,$
  color=0,xrange=range(x_m)/10000000.,yrange=range(y_m),$
  title=titleString+'raw profile',/nodata,ytickformat='(i)'
oplot,x_m[*,0]/10000000.,y_m[*,0],color=colors[0]
for i=1,nfiles-1 do begin
  oplot,x_m[*,i]/10000000.,y_m[*,i],color=colors[i]
endfor
legend,legstr,color=colors,position=12
if ps ne 0 then begin
  DEVICE, /CLOSE 
  SET_PLOT_default
endif

;create leveled profile plot and data
if ps ne 0 then begin
  file_mkdir,img_dir
  SET_PLOT, 'PS'
  DEVICE, filename=img_dir+path_sep()+outname+'_profile.eps', /COLOR,/encapsulated  
endif else window,1
plot,[0],[0],xtitle='x (mm)',ytitle='y (A)',background=255,$
  color=0,xrange=range(x_roi_m)/10000000.,yrange=range(y_roi_m),$
  title=titleString+'leveled profile',/nodata,ytickformat='(i)'
oplot,x_roi_m[*,0]/10000000.,y_roi_m[*,0],color=colors[0]
for i=1,nfiles-1 do begin
  oplot,x_roi_m[*,i]/10000000.,y_roi_m[*,i],color=colors[i]
endfor
legend,legstr,color=colors,position=12
if ps ne 0 then begin
  DEVICE, /CLOSE 
  SET_PLOT_default
endif

;create PSD plot and data
if ps ne 0 then begin
  file_mkdir,img_dir
  SET_PLOT, 'PS'
  DEVICE, filename=img_dir+path_sep()+outname+'_psd.eps', /COLOR,/encapsulated  
endif else window,2
plot,[0],[0],/xlog,/ylog,ytickformat='exponent',$
  xtitle='Frequency (mm^-1)',ytitle='Amplitude ('+Greek('mu')+'!3m!E3!N)',background=255,color=0,$
  title=titleString+'PSD from leveled profile',/nodata,$
  xrange=range(f_m)*10000000.,yrange=range(psd_m)*10d-12
oplot,f_m[*,0]*10000000.,psd_m[*,0]*10d-12,color=colors[0]
oplot,f_m[*,0]*10000000.,fitpars_m[0,0]/(ABS(f_m[*,0])^fitpars_m[1,0])*10d-12,color=colors[0],linestyle=2
for i=1,nfiles-1 do begin
  oplot,f_m[*,i]*10000000.,psd_m[*,i]*10d-12,color=colors[i]
  oplot,f_m[*,i]*10000000.,fitpars_m[0,i]/(ABS(f_m[*,i])^fitpars_m[1,i])*10d-12,color=colors[i],linestyle=2
;  S=K_n/(ABS(F)^N)
;  S=fitpars_m[0,i]/(ABS(F)^fitpars_m[1,i])
endfor
highlightLam=[0.01,0.03] ;lambda in mm^-1    
for i =0,n_elements(highlightLam)-1 do begin
  oplot,[highlightLam[i],highlightLam[i]],10^!Y.Crange,color=6,linestyle=2
endfor
if n_elements(fCut) ne 0 then begin
    for i=0,nfiles-1 do begin
        oplot,[min(f_m[*,i]),min(f_m[*,i])]*fCut*10000000.,10^!Y.Crange,color=colors[i],linestyle=3
        oplot,[max(f_m[*,i]),max(f_m[*,i])]/fCut*10000000.,10^!Y.Crange,color=colors[i],linestyle=3
    endfor
endif
legend,legstr,color=colors,position=12
if ps ne 0 then begin
  DEVICE, /CLOSE 
  SET_PLOT_default
endif

;create stats plot and data
;; calculate data
zstats_m=histostats(y_roi_m[where(finite(y_roi_m[*,0])),0],$
    nbins=nbins,/noplot,locations=zlocations,hist=zhist,$
    /normalize,min=min(y_roi_m,/nan),max=max(y_roi_m,/nan))
zlocations_m=zlocations
hist_m=zhist
for i=1,nfiles-1 do begin
zstats_m=[[zstats_m],[histostats(y_roi_m[where(finite(y_roi_m[*,i])),i],$
    nbins=nbins,/noplot,locations=zlocations,hist=zhist,$
    /normalize,min=min(y_roi_m,/nan),max=max(y_roi_m,/nan))]]
zlocations_m=concatenate(zlocations_m,zlocations,2)
hist_m=concatenate(hist_m,zhist,2)
endfor
;; plot data. The plot needs to be done in a different step to account for the vertical range.
if ps ne 0 then begin
  file_mkdir,img_dir
  SET_PLOT, 'PS'
  DEVICE, filename=img_dir+path_sep()+outname+'_hist.eps', /COLOR,/encapsulated  
endif else window,3
expansionFactor=1.1
plot,[0],[0],title=titleString+'Distribution of heights for leveled data',$
    background=255,color=0,xtitle='z (A)',ytitle='Fraction',$
    xrange=range(y_roi_m),yrange=[0,max(hist_m,/nan)*expansionFactor]
oplot,zlocations_m[*,0],hist_m[*,0],color=colors[0],psym=10
for i=1,nfiles-1 do begin
  oplot,zlocations_m[*,i],hist_m[*,i],color=colors[i],psym=10
endfor
legend,legstr,color=colors,position=12
if ps ne 0 then begin
  DEVICE, /CLOSE 
  SET_PLOT_default
endif

;create diff plot and data - raw profiles
;;calculate differences in raw profiles

;allcouples=(nfiles le maxallcouplesDiff)?1:0
;ydiff_m=difffunc(x_m,y_m,x_mbase=xdiff_m,/removeBase,xIndex=xIndex,allcouples=allcouples,couples=couples,/force)

if (nfiles le maxallcouplesDiff) then begin
  allcouples=1
  removebase=0
endif else begin
  allcouples=0
  removebase=1
endelse
ydiff_m=difffunc(x_m,y_m,x_mbase=xdiff_m,removebase=removebase,xIndex=xIndex,allcouples=allcouples,couples=couples)
ndiffvectors=nvectors(ydiff_m)
diffcolors=transpose(colors[couples[1,*]])
difflinestyles=transpose(couples[0,*])
;diffmask=where(indgen(nfiles) ne baseIndex) 
for i=0,ndiffvectors-1 do begin
  diffleg=(i eq 0)?strjoin(reverse(legstr[couples[*,i]]),' - '):[diffleg,strjoin(reverse(legstr[couples[*,i]]),' - ')]
endfor
multi_plot,xdiff_m/10000000.,ydiff_m,psfile=(ps ne 0)?img_dir+path_sep()+outname+'_differences_raw.eps':'',$
  xtitle='x (mm)',ytitle='Delta y (A)',background=255,$
  colors=diffcolors,linestyles=difflinestyles,$
  legend=diffleg,$
  title='Difference in raw profiles',ytickformat='(i)'
 ;;stats calculation
diffstats_m=histostats(ydiff_m[where(finite(ydiff_m[*,0])),0],$
    nbins=nbins,/noplot,locations=difflocations,hist=diffhist,$
    /normalize,min=min(ydiff_m,/nan),max=max(ydiff_m,/nan))
difflocations_m=difflocations
diffhist_m=diffhist
if ndiffvectors gt 1 then begin
  for i=1,ndiffvectors-1 do begin
    diffstats_m=[[diffstats_m],[histostats(ydiff_m[where(finite(ydiff_m[*,i])),i],$
        nbins=nbins,/noplot,locations=difflocations,hist=diffhist,$
        /normalize,min=min(ydiff_m,/nan),max=max(ydiff_m,/nan))]]
    difflocations_m=concatenate(difflocations_m,difflocations,2)
    diffhist_m=concatenate(diffhist_m,diffhist,2)
  endfor
endif
 ;;histogram plot. The plot needs to be done in a different step to account for the vertical range.
if ps ne 0 then begin
  file_mkdir,img_dir
  SET_PLOT, 'PS'
  DEVICE, filename=img_dir+path_sep()+outname+'_diffhist_raw.eps', /COLOR,/encapsulated  
endif else window,4
expansionFactor=1.1
plot,[0],[0],title=titleString+'distribution of differences in raw profile',$
    background=255,color=0,xtitle='z (A)',ytitle='Fraction of total number',$
    xrange=range(ydiff_m),yrange=[0,max(diffhist_m)*expansionFactor]
oplot,difflocations_m[*,0],diffhist_m[*,0],color=diffcolors[0],psym=10,linestyle=difflinestyles[0]
for i=1,ndiffvectors-1 do begin
  oplot,difflocations_m[*,i],diffhist_m[*,i],color=diffcolors[i],psym=10,linestyle=difflinestyles[i]
endfor
legend,diffleg,color=diffcolors,position=12
if ps ne 0 then begin
  DEVICE, /CLOSE 
  SET_PLOT_default
endif

;create diff plot and data - leveled profiles
;;calculate differences in leveled profiles
ydiff_roi_m=difffunc(x_roi_m,y_roi_m,x_mbase=xdiff_roi_m,removeBase=removeBase,allcouples=allcouples,couples=couples)
ndiffvectors=nvectors(ydiff_roi_m)
;diffmask=where(indgen(nfiles) ne baseIndex2)
multi_plot,xdiff_roi_m/10000000.,ydiff_roi_m,psfile=(ps ne 0)?img_dir+path_sep()+outname+'_differences_lev.eps':'',$
  xtitle='x (mm)',ytitle='Delta y (A)',background=255,$
  colors=diffcolors,linestyles=difflinestyles,$
  legend=diffleg,$
  title='Difference in leveled profiles',ytickformat='(i)'
 ;;stats calculation
diff_roistats_m=histostats(ydiff_roi_m[where(finite(ydiff_roi_m[*,0])),0],$
    nbins=nbins,/noplot,locations=diff_roilocations,hist=diff_roihist,$
    /normalize,min=min(ydiff_roi_m,/nan),max=max(ydiff_roi_m,/nan))
diff_roilocations_m=diff_roilocations
diff_roihist_m=diff_roihist
if ndiffvectors gt 1 then begin
  for i=1,ndiffvectors-1 do begin
    diff_roistats_m=[[diff_roistats_m],[histostats(ydiff_roi_m[where(finite(ydiff_roi_m[*,i])),i],$
        nbins=nbins,/noplot,locations=diff_roilocations,hist=diff_roihist,$
        /normalize,min=min(ydiff_roi_m,/nan),max=max(ydiff_roi_m,/nan))]]
    diff_roilocations_m=concatenate(diff_roilocations_m,diff_roilocations,2)
    diff_roihist_m=concatenate(diff_roihist_m,diff_roihist,2)
  endfor
endif
 ;;histogram plot. The plot needs to be done in a different step to account for the vertical range.
if ps ne 0 then begin
  file_mkdir,img_dir
  SET_PLOT, 'PS'
  DEVICE, filename=img_dir+path_sep()+outname+'_diffhist_lev.eps', /COLOR,/encapsulated  
endif else window,4
expansionFactor=1.1
plot,[0],[0],title='Distribution of differences in leveled profile',$
    background=255,color=0,xtitle='z (A)',ytitle='Fraction of total number',$
    xrange=range(ydiff_roi_m),yrange=[0,max(diff_roihist_m)*expansionFactor]
oplot,diff_roilocations_m[*,0],diff_roihist_m[*,0],color=diffcolors[0],psym=10,linestyle=difflinestyles[0]
for i=1,ndiffvectors-1 do begin
  oplot,diff_roilocations_m[*,i],diff_roihist_m[*,i],color=diffcolors[i],psym=10,linestyle=difflinestyles[i]
endfor
legend,diffleg,color=diffcolors,position=12
if ps ne 0 then begin
  DEVICE, /CLOSE 
  SET_PLOT_default
endif

;restore graphics settings
if ps ne 0 then begin
  !P.thick=thstore[0]
  !X.thick=thstore[1]
  !y.thick=thstore[2]
  !P.charthick=thstore[3]
endif

;!P.thick=1
;!X.thick=1
;!y.thick=1
;!P.charthick=1

;--------------- 3 - creation of latex report ---------------------------- 
;create report tex file and compile it
;;create stats table
statsheader=['Mean','PV','Min','Max','Rms',$
              'R!$_a$!','Stndrd dev of mean','Variance','Skewness','Residual kurtosis'] ;complete list of names for the fields
conversion=[10.^(-4),10.^(-4),10.^(-4),10.^(-4),10.^(-4),10.^(-4),10.^(-4),10.^(-4),1.,1.] ;complete list of conversion factors for the fields
;conversion=rebin(conversion,n_elements(statsheader),nfiles)
;
statsmask=[0,2,3,1,4,5,8,9] ;used to select and sort names and values
formatstring='(a,'+strjoin(replicate('f8.4',nfiles),',')+')'
vals=zstats_m[statsmask,*]*rebin(conversion[statsmask],n_elements(statsmask),nfiles)
statstable=makelatextable(string(vals),rowheader=statsheader[statsmask],$
   colheader=latextableline(['','\emph{'+legstr+'}']),format=formatstring)
   
;;create diff raw table
statsmask=[0,2,3,1,4,5] ;used to select and sort names and values
formatstring='(a,'+strjoin(replicate('f8.4',ndiffvectors),',')+')'
vals=diffstats_m[statsmask,*]*rebin(conversion[statsmask],n_elements(statsmask),ndiffvectors)
diffstatstable=makelatextable(string(vals),rowheader=statsheader[statsmask],$
   colheader=latextableline(['','\emph{'+diffleg+'}']),format=formatstring)

;;create diff leveled table
statsmask=[0,2,3,1,4,5] ;used to select and sort names and values
formatstring='(a,'+strjoin(replicate('f8.4',ndiffvectors),',')+')'
vals=diff_roistats_m[statsmask,*]*rebin(conversion[statsmask],n_elements(statsmask),ndiffvectors)
diff_roistatstable=makelatextable(string(vals),rowheader=statsheader[statsmask],$
   colheader=latextableline(['','\emph{'+diffleg+'}']),format=formatstring)
   
;now all data are loaded (and figure generated if ps=1)
;If a report object is passed append the text, otherwise create it.
if n_elements(includeSections) ne 0 then begin
  createReport=(obj_valid(report) eq 0)
  if createReport then report=obj_new('lr',outfolder+path_sep()+outname+'_report.tex',title=title,$
                  author=author,level=sectionlevel)
  
  for j=0,n_elements(includeSections)-1 do begin ;add sections to report in the order listed in includeSections
    sectionIndex=includeSections[j] 
      
    ;General description
    if sectionIndex eq 0 or sectionIndex eq -1 then begin
      if (sectionlevel eq report->get_lowestLevel()) then begin
        report->section,sectionlevel,'Samples '+outname,nonum=nonum
      endif else report->section,sectionlevel,outname,nonum=nonum,newpage=newpage
      report->append,'\emph{Results folder: '+outfolder+'}\\'
      report->append,'\emph{Outname: '+outname+'}'
      if n_elements(text) ne 0 then report->append,text
      report->list,'\emph{'+legstr+'}: '+filelist
    endif
    
    ;Raw data
    if sectionIndex eq 1 or sectionIndex eq -1 then begin  
        report->section,sectionlevel+1,'Scan Data',nonum=nonum,newpage=0
        parstable=makelatextable(string([scan_pars_m,partialStats_m]),rowheader=['Stylus radius (!$\mu$!m)',$
            'Full scan Length (!$\mu$!m)','N of points', 'X step (!$\mu$!m)','Vertical range (k\AA)','Roi Start (!$\mu$!m)',$
            'Roi End (!$\mu$!m)','Rms (k\AA, tilt removed)','R!$_a$! (k\AA, t.r.)','TIR (k\AA, t.r.)'],$
            colheader=latextableline(['','\emph{'+legstr+'}']))
        report->table,parstable,'p{4cm}'+strjoin(replicate('p{2cm}',nfiles)),caption='Scan parameters.' ;,autowidth='0.9\textwidth'
        report->figure,img_dir+path_sep()+outname+'_rawdata',caption='Raw data profile.',parameters='width=0.75\textwidth'
    endif 

    ;Leveling and profile stats
    if sectionIndex eq 2 or sectionIndex eq -1 then begin
      report->section,sectionlevel+1,'Profile analysis',nonum=nonum,newpage=newpage
      ;formatstring='(a,'+strjoin(replicate('f8.4',nfiles),',')+')'
      leveltable=makelatextable(string(level_m),rowheader=['a!$_0$!','a!$_1$!','a!$_2$!'],$
         colheader=latextableline(['','\emph{'+legstr+'}']));,format=formatstring)
      report->table,leveltable,'p{1cm}'+strjoin(replicate('p{2cm}',nfiles)),$
          caption='Components removed for leveling (fit with 2!$^\mathrm{nd}$! order polynomial), values in \AA:';,$
          ;autowidth='0.9\textwidth'
      report->figure,img_dir+path_sep()+outname+'_profile',caption='Profile after leveling.',parameters='width=0.75\textwidth'
      report->table,statstable,'p{3cm}'+strjoin(replicate('p{2cm}',nfiles)),caption='Statistics after leveling, values in !$\mu$!m,'+$
          ' skewness and kurtosis are dimensionless.';,autowidth='0.9\textwidth'
      report->figure,img_dir+path_sep()+outname+'_hist',caption='Distribution of heights for leveled data.',$
          parameters='width=0.75\textwidth'
    endif
    
    if sectionIndex eq 3 or sectionIndex eq -1 then begin
    ;PSD average (includes calculation)
      if n_elements(groups) eq 0 then begin
        ;check that all the psd are calculated over the same frequency points
        xchk=f_m[*,0]
        for i=1,nfiles-1 do begin
          if array_equal(f_m[*,i],xchk) ne 1 then begin 
            s= 'Frequency of '+string(i,format='(i2)')+'-th vector does not correspond to the 0th frequency.'
            s=s+ ' Average of PSD not performed'
            result=dialog_message(s)
            goto, exitPsdAvg
          endif
        endfor
        averagePSD=total(psd_m,2)/nfiles
        
        ;fit
        if n_elements(fCut) ne 0 then fitrange=[min(xchk)*4,max(xchk)/4]
        Result=PSD_FIT(xchk,averagepsd,avgPARS,range=fitrange)
        fitavgpsd=avgpars
        
        if ps ne 0 then begin
          file_mkdir,img_dir
          SET_PLOT, 'PS'
          DEVICE, filename=img_dir+path_sep()+outname+'_avg_psd.eps', /COLOR,/encapsulated  
        endif else window,5
        plot,xchk*10000000.,averagePSD*10d-12,/xlog,/ylog,ytickformat='exponent',$
          xtitle='Frequency (mm^-1)',ytitle='Amplitude (um^3)',background=255,color=0,$
          title=titleString+'average PSD from '+string(nfiles,format='(i2)')+' profiles'
        oplot,xchk*10000000.,fitavgpsd[0]/(ABS(F)^fitavgpsd[1])*10d-12,color=colors[0],linestyle=2
        highlightLam=[0.01,0.03] ;lambda in mm^-1    
        for i =0,n_elements(highlightLam)-1 do begin
          oplot,[highlightLam[i],highlightLam[i]],10^!Y.Crange,color=6,linestyle=2
        endfor
        if n_elements(fCut) ne 0 then begin
            for i=0,nfiles-1 do begin
                oplot,[min(f_m[*,i]),min(f_m[*,i])]*fCut*10000000.,10^!Y.Crange,color=colors[i],linestyle=3
                oplot,[max(f_m[*,i]),max(f_m[*,i])]/fCut*10000000.,10^!Y.Crange,color=colors[i],linestyle=3
            endfor
        endif
        legend,['Average PSD','Fit'],position=12,color=[0,colors[0]]
        if ps ne 0 then begin
          DEVICE, /CLOSE 
          SET_PLOT_default
        endif
      
        report->section,sectionlevel+1,'Average PSD',nonum=nonum,newpage=newpage      
        report->figure,img_dir+path_sep()+outname+'_avg_psd',caption='Average PSD from \emph{'+strjoin(legstr,'}, \emph{')+'}.'+$
                ' Fit parameters (according to !$PSD(f)=K|f|^{-N}$!): '+strjoin((['K=','N=']+string(fitavgpsd)),', '),$
                parameters='width=0.75\textwidth'
      endif else begin
    
       ;summary of PSD average for groups (includes calculation)
        ngroups=n_elements(groups)
        gcolors=plotcolors(ngroups)
        grange_m=intarr(2,ngroups)
        grange_m[1,*]=total(groups,/integer,/cumulative)-1
        grange_m[0,*]=grange_m[1,*]-groups+1
        startvec=0
        if n_elements(groupnames) ne ngroups then begin
          if n_elements(groupnames) eq 0 then print,'No group names provided, standard names used.'$
          else begin
            print,'Size of groupnames (',n_elements(groupnames),') does not corresponds to the number of groups (',ngroups,'), standard names used.'
          endelse
          groupnames='group #'+strtrim(sindgen(ngroups+1),2) 
        endif
        gLegend=strarr(ngroups)
        for i=0,ngroups-1 do begin
          strrange=strjoin(strtrim(grange_m[*,i],2),' - ')
          gLegend[i]=groupnames[i]+': files '+ strrange
        endfor
        if ps ne 0 then begin
          file_mkdir,img_dir
          SET_PLOT, 'PS'
          DEVICE, filename=img_dir+path_sep()+outname+'_avg_psd_g.eps', /COLOR,/encapsulated  
        endif else window,5
        for k=0,ngroups-1 do begin
          grange=grange_m[*,k]
          glen=grange_m[1,k]-grange_m[0,k]+1
          ;--------------------------------
          ;check that all the psd are calculated over the same frequency points
          xchk=f_m[*,grange[0]]
          for i=grange[0]+1,grange[1] do begin
            if array_equal(f_m[*,i],xchk) ne 1 then begin 
              s= 'Frequency of '+string(i,format='(i2)')+'-th vector does not correspond to the 0th frequency.'
              s=s+ ' Average of PSD not performed'
              result=dialog_message(s)
              goto, exitPsdAvg
            endif
          endfor
          averagePSD=total(psd_m[*,grange[0]:grange[1]],2)/glen
          ;fit     
          if n_elements(fCut) ne 0 then fitrange=[min(xchk)*4,max(xchk)/4]     
          Result=PSD_FIT(xchk,averagepsd,fitavgpsd,range=fitrange)
          f2=xchk
          psd2=averagePSD
          integral = 2*INT_TABULATED(f2,psd2,/sort )
          fitavgpsd_m=(k eq 0)?[integral,fitavgpsd]:[[fitavgpsd_m],[integral,fitavgpsd]]
          
          if k eq 0 then begin
            plot,[0],[0],/nodata,/xlog,/ylog,ytickformat='exponent',$
            xtitle='Frequency (mm^-1)',ytitle='Amplitude (um^3)',background=255,color=0,$
            title=titleString+'average PSD for '+string(ngroups,format='(i2)')+' groups of profiles',$
            xrange=range(f_m)*10000000.,yrange=range(psd_m)*10d-12
            oplot,xchk*10000000.,averagePSD*10d-12,color=gcolors[0]
            oplot,xchk*10000000.,fitavgpsd[0]/(ABS(F)^fitavgpsd[1])*10d-12,color=gcolors[0],linestyle=2
          endif else begin
            oplot,xchk*10000000.,averagePSD*10d-12,color=gcolors[k]
            oplot,xchk*10000000.,fitavgpsd[0]/(ABS(F)^fitavgpsd[1])*10d-12,color=gcolors[k],linestyle=2
          endelse
        endfor
        highlightLam=[0.01,0.03] ;lambda in mm^-1    
        for i =0,n_elements(highlightLam)-1 do begin
          oplot,[highlightLam[i],highlightLam[i]],10^!Y.Crange,color=0,linestyle=2
        endfor
        if n_elements(fitrange) ne 0 then begin
            oplot,[fitrange[0],fitrange[0]]*10000000.,10^!Y.Crange,color=fsc_color('blue'),linestyle=3
            oplot,[fitrange[1],fitrange[1]]*10000000.,10^!Y.Crange,color=fsc_color('blue'),linestyle=3
        endif
        legend,gLegend,position=12,color=gcolors
        if ps ne 0 then begin
          DEVICE, /CLOSE 
          SET_PLOT_default
        endif
        report->section,sectionlevel+1,outname+': average PSD for '+strtrim(string(ngroups),2)+$
            ' groups of profiles',nonum=nonum,newpage=newpage      
        report->figure,img_dir+path_sep()+outname+'_avg_psd_g',caption='Average PSD for '+strtrim(string(ngroups),2)+' groups of '+$
                'profiles. Fit parameters are reported in table~\ref{!tab:'+outname+'_g!}.',$
                parameters='width=0.75\textwidth'
        ;table of results
        conversion=rebin([10.^(-4),10.^(-12),1.],3,ngroups)
        psdtable_g=makelatextable(transpose(string(fitpars_m*conversion)),$
              rowheader=['\emph{'+gLegend+'}'],$
              colheader=latextableline(['','(Integrated PSD)!$^{\frac{1}{2}}$! (!$\mu$!m)',$
              'K (!$\mu$!m!$^3$!) from fit','N from fit']))
        report->table,psdtable_g,'p{6cm}'+strjoin(replicate('p{2cm}',ngroups)),caption='Summary of average PSD and fit '+$
            '(according to !$PSD(f)=K|f|^{-N}$!).'
        
        conversion=rebin([10.^(-4),10.^(-4),1.,10.^(-12),1.],5,nfiles)
        psdtable=makelatextable(transpose(string([normpars_m,fitpars_m]*conversion)),$
              colheader=latextableline(['','(Integrated PSD)!$^{\frac{1}{2}}$! (!$\mu$!m)','$\sigma$ (!$\mu$!m)',$
              'Scaling factor','K (!$\mu$!m!$^3$!) from fit','N from fit']),$
              rowheader='\emph{'+legstr+'}')
        report->table,psdtable,'p{3cm}'+strjoin(replicate('p{2cm}',nfiles)),caption='Summary of values for '+$
            'the single profile (fit according to !$PSD(f)=K|f|^{-N}$!).~\label{!tab:'+outname+'_g!}.';,autowidth='0.9\textwidth'
            
      endelse
    endif
    exitPsdAvg:

    ;Differences raw
    if sectionIndex eq 4 or sectionIndex eq -1 then begin
      report->section,sectionlevel+1,'Differences between raw data',nonum=nonum,newpage=newpage
      formatstring='(a,'+strjoin(replicate('f8.4',nfiles),',')+')'  
      report->figure,img_dir+path_sep()+outname+'_differences_raw',caption=outname+': Differences in leveled profile',$
      parameters='width=0.75\textwidth'
      report->figure,img_dir+path_sep()+outname+'_diffhist_raw',caption=outname+$
        ': Distribution of differences in heights (measured profiles).',parameters='width=0.75\textwidth'
      report->table,diffstatstable,'p{3cm}'+strjoin(replicate('p{2cm}',nfiles)),$
        caption=outname+': Statistics from differences in measured profile, values in !$\mu$!m.';,autowidth='0.9\textwidth'
    endif
    
    ;Differences leveled
    if sectionIndex eq 5 or sectionIndex eq -1 then begin
      report->section,sectionlevel+1,'Differences between leveled data',nonum=nonum,newpage=newpage
      formatstring='(a,'+strjoin(replicate('f8.4',nfiles),',')+')'  
      report->figure,img_dir+path_sep()+outname+'_differences_lev',caption=outname+': Differences in leveled profile' $
        ,parameters='width=0.75\textwidth'
      report->figure,img_dir+path_sep()+outname+'_diffhist_lev',caption=outname+': Distribution of differences in heights'$
        ,parameters='width=0.75\textwidth'
      report->table,diff_roistatstable,'p{3cm}'+strjoin(replicate('p{2cm}',nfiles)),$
          caption=outname+': Statistics from differences in leveled profile, values in !$\mu$!m.';,autowidth='0.9\textwidth'
    endif

    ;PSD analysis and fit
    if sectionIndex eq 6 or sectionIndex eq -1  then begin
      report->section,sectionlevel+1,'PSD analysis',nonum=nonum,newpage=newpage
      report->figure,img_dir+path_sep()+outname+'_psd',caption='PSD after leveling, smoothing with Hann window and normalization.',$
              parameters='width=0.75\textwidth'
              ;normpars=[integral,var,1/integral*var]
      conversion=rebin([10.^(-4),10.^(-4),1.,10.^(-12),1.],5,nfiles)
      psdtable=makelatextable(string([normpars_m,fitpars_m]*conversion),$
            rowheader=['(Integrated PSD)!$^{\frac{1}{2}}$! (!$\mu$!m)','!$\sigma$! (!$\mu$!m)',$
            'Scaling factor','K (!$\mu$!m!$^3$!) from fit','N from fit'],$
            colheader=latextableline(['','\emph{'+legstr+'}']))
      report->table,psdtable,'p{3cm}'+strjoin(replicate('p{2cm}',nfiles)),caption='Fit parameters for PSD '+$
          '(according to !$PSD(f)=K|f|^{-N}$!).';,autowidth='0.9\textwidth'
    endif
  endfor
  
  if createReport then begin
    report->compile,2,/pdf,/clean
    obj_destroy,report
  endif
endif

end

pro test_multi_psd

  roi_um= [1000,59000]
  nbins=100
  ;obj_destroy,report
  
  ;filelist=['H:\psf\vincenzo_glass1\A01_00F_L.csv',$
  ;          'H:\psf\vincenzo_glass1\A01_00F_C.csv',$
  ;          'H:\psf\vincenzo_glass1\A01_00F_R.csv']
  filelist=['/home/cotroneo/Desktop/PSD/Vincenzo_glass1/A01_00F_L.csv',$
            '/home/cotroneo/Desktop/PSD/Vincenzo_glass1/A01_00F_C.csv',$
            '/home/cotroneo/Desktop/PSD/Vincenzo_glass1/A01_00F_R.csv']
  author='Vincenzo Cotroneo'       
  outfolder='/home/cotroneo/Desktop/PSD/Vincenzo_glass1/test1'
  outname='A01_00F'   
  title='PSD analysis of '+outname+' files'
  sectionlevel=1
  labels=stripext(map('file_basename',filelist)) 
           
  multipsd,filelist,roi_um=roi_um,nbins=nbins,sectionlevel=sectionlevel,outname=outname,$
    report=report,author=author,title=title,outfolder=outfolder,labels=labels,/nonum,includeSections=[0,1,2,4,5,6]
end

test_multi_psd
  
end