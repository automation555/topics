default: slides.pdf


%.view: %.pdf  
	evince $<

%.print: %.pdf
	lpr $<


%.pdf: %.tex 
	pdflatex $<

%.pdf: %.svg
#	inkscape --export-pdf=$@ $<
	convert $< $@

slides.pdf: begin.pdf mid.pdf 


%.tex: %.lhs
	lhs2TeX $< > $@


%.tex: %.dot
	dot -Txdot $< | dot2tex --texmode=raw --figonly > $@
#	dot2tex --preproc $< | dot2tex --figonly > $@

