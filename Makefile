
DATA_DIR = data

PBS   = $(wildcard ${DATA_DIR}/*.progressionbackup)
TXTS  = ${PBS:.progressionbackup=.txt}

all: txts

txts: ${TXTS}
${TXTS}: %.txt: %.progressionbackup Makefile dump.pl
	./dump.pl $< > $@
