# pgloader build tools

POMO_PATCH = $(realpath patches/postmodern-send-copy-done.patch)
ASDF_CONFD = ~/.config/common-lisp/source-registry.conf.d
ASDF_CONF  = $(ASDF_CONFD)/projects.conf

LIBS       = build/libs.stamp
BUILDAPP   = build/buildapp
MANIFEST   = build/manifest.ql
PGLOADER   = build/pgloader.exe

all: $(PGLOADER)

docs:
	pandoc pgloader.1.md -o pgloader.1
	pandoc pgloader.1.md -o pgloader.html
	pandoc pgloader.1.md -o pgloader.pdf

~/quicklisp/local-projects/cl-abnf:
	git clone https://github.com/dimitri/cl-abnf.git $@

~/quicklisp/local-projects/cl-db3:
	git clone https://github.com/dimitri/cl-db3.git $@

~/quicklisp/local-projects/Postmodern:
	git clone https://github.com/marijnh/Postmodern.git $@
	cd ~/quicklisp/local-projects/Postmodern/ && patch -p1 < $(POMO_PATCH)

~/quicklisp/local-projects/cl-csv:
	git clone -b empty-strings-and-nil https://github.com/dimitri/cl-csv.git $@

cl-abnf: ~/quicklisp/local-projects/cl-abnf ;
cl-db3: ~/quicklisp/local-projects/cl-db3 ;
cl-csv: ~/quicklisp/local-projects/cl-csv ;
postmodern: ~/quicklisp/local-projects/Postmodern ;

~/quicklisp/setup.lisp:
	curl -o ~/quicklisp.lisp http://beta.quicklisp.org/quicklisp.lisp
	sbcl --load ~/quicklisp.lisp                  \
             --eval '(quicklisp-quickstart:install)'  \
             --eval '(quit)'

quicklisp: ~/quicklisp/setup.lisp ;

$(ASDF_CONF):
	mkdir -p $(ASDF_CONFD)
	echo '(:tree "/vagrant")' > $@

asdf-config: $(ASDF_CONF) ;

$(LIBS): quicklisp $(ASDF_CONF) cl-abnf cl-db3 postmodern cl-csv
	sbcl --load ~/quicklisp/setup.lisp                             \
             --eval '(ql:quickload "pgloader")'                        \
             --eval '(quit)'
	touch $@

libs: $(LIBS) ;

$(MANIFEST): libs
	sbcl --load ~/quicklisp/setup.lisp                                 \
             --eval '(ql:write-asdf-manifest-file "./build/manifest.ql")'  \
             --eval '(quit)'

$(BUILDAPP): quicklisp
	sbcl --load ~/quicklisp/setup.lisp                          \
             --eval '(ql:quickload "buildapp")'                     \
             --eval '(buildapp:build-buildapp "./build/buildapp")'  \
             --eval '(quit)'

$(PGLOADER): $(MANIFEST) $(BUILDAPP)
	./build/buildapp --logfile /tmp/build.log                \
                         --asdf-tree ~/quicklisp/local-projects  \
                         --manifest-file ./build/manifest.ql     \
                         --asdf-tree ~/quicklisp/dists           \
                         --asdf-path .                           \
                         --load-system pgloader                  \
                         --entry pgloader:main                   \
                         --dynamic-space-size 4096               \
                         --compress-core                         \
                         --output $@

pgloader: $(PGLOADER) ;

test:
	$(MAKE) PGLOADER=$(realpath $(PGLOADER)) -C test all

check: test ;

.PHONY: test