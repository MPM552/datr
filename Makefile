create:
	singularity build --fakeroot datr.sif datr.def
run:
	./datr.sif
