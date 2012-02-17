index.html: README.markdown
	pandoc -s $^ -o $@
