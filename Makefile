I_D = draft-ietf-netmod-yang-json
REVNO = 01
DATE ?= $(shell date +%F)
MODULES =
FIGURES = ex-get-reply.json
EXAMPLE_BASE = ex
EXAMPLE_TYPE = get-reply
baty = $(EXAMPLE_BASE)-$(EXAMPLE_TYPE)
EXAMPLE_INST = $(baty).xml
PYANG_OPTS =

artworks = $(addsuffix .aw, $(yams)) $(EXAMPLE_INST).aw \
	   $(addsuffix .aw, $(FIGURES))
idrev = $(I_D)-$(REVNO)
yams = $(addsuffix .yang, $(MODULES))
xsldir = .tools/xslt
xslpars = --stringparam date $(DATE) --stringparam i-d-name $(I_D) \
	  --stringparam i-d-rev $(REVNO)
schemas = $(baty).rng $(baty).sch $(baty).dsrl
y2dopts = -t $(EXAMPLE_TYPE) -b $(EXAMPLE_BASE)

.PHONY: all validate clean rnc refs

all: $(idrev).txt

$(idrev).xml: $(I_D).xml $(artworks) figures.ent
	@xsltproc $(xslpars) $(xsldir)/upd-i-d.xsl $< | xmllint --noent -o $@ -

$(idrev).txt: $(idrev).xml
	@xml2rfc --dtd=.tools/schema/rfc2629.dtd $<

hello.xml: $(yams) hello-external.ent
	@echo '<hello xmlns="urn:ietf:params:xml:ns:netconf:base:1.0">' > $@
	@echo '<capabilities>' >> $@
	@echo '<capability>urn:ietf:params:netconf:base:1.1</capability>' >> $@
	@for m in $(yams); do \
	  capa=$$(pyang $(PYANG_OPTS) -f capability --capability-entity $$m); \
	  if [ "$$capa" != "" ]; then \
	    echo "<capability>$$capa</capability>" >> $@; \
	  fi \
	done
	@cat hello-external.ent >> $@
	@echo '</capabilities>' >> $@
	@echo '</hello>' >> $@

refs: figures.ent $(artworks)
	xsltproc --output stdrefs.ent $(xsldir)/get-refs.xsl $(I_D).xml

yang.ent: $(yams)
	@echo '<!-- External entities for files with modules -->' > $@
	@for f in $^; do                                                 \
	  echo '<!ENTITY '"$$f SYSTEM \"$$f.aw\">" >> $@;          \
	done
ifneq ($EXAMPLE_INST,)
	@echo '<!ENTITY '"$(EXAMPLE_INST) SYSTEM \"$(EXAMPLE_INST).aw\">" >> $@
endif

figures.ent: $(FIGURES)
ifeq ($(FIGURES),)
	@touch $@
else
	@echo '<!-- External entities for files with figures -->' > $@; \
	for f in $^; do                                            \
	  echo '<!ENTITY '"$$f SYSTEM \"$$f.aw\">" >> $@;  \
	done
endif

%.yang: %.yinx
	@xsltproc $(xsldir)/canonicalize.xsl $< | \
	  xsltproc --xinclude --output $@ $(xslpars) $(xsldir)/yin2yang.xsl -

ietf-%.yang.aw: ietf-%.yang
	@pyang $(PYANG_OPTS) --ietf $<
	@echo '<artwork>' > $@
	@echo '<![CDATA[<CODE BEGINS> file '"\"$*@$(DATE).yang\"" >> $@
	@echo >> $@
	@cat $< >> $@
	@echo >> $@
	@echo '<CODE ENDS>]]></artwork>' >> $@

%.aw: %
	@echo '<artwork><![CDATA[' > $@; \
	cat $< >> $@;                    \
	echo ']]></artwork>' >> $@

model.xsl: hello.xml
	pyang -f jsonxsl -o $@ -L $<

$(baty).json: model.xsl $(EXAMPLE_INST)
	xsltproc -o $@ $^

$(schemas): hello.xml
	yang2dsdl $(y2dopts) -L $<

%.rnc: %.rng
	trang -I rng -O rnc $< $@

rnc: $(baty).rnc

validate: $(EXAMPLE_INST) $(schemas)
	@yang2dsdl -j -s $(y2dopts) -v $<

model.tree: hello.xml
	pyang $(PYANG_OPTS) -f tree -o $@ -L $<

clean:
	@rm -rf hello.xml $(idrev).* $(artworks) figures.ent $(baty).json
