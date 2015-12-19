
DATA_DIR = data

PBS   = $(wildcard ${DATA_DIR}/*.progressionbackup)
JSONS = ${PBS:.progressionbackup=.json}

json: ${JSONS}
${JSONS}: %.json: %.progressionbackup Makefile
	base64 --decode < $< > $@
