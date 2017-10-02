FROM osevg/workshopper:ruby

ENV CONTENT_URL_PREFIX="file:///opt/data/workshopper-content"
ENV WORKSHOPS_URLS="file:///opt/data/workshopper-content/_devops-workshop.yml"
ENV DEFAULT_LAB="devops"

ADD *.adoc /opt/data/workshopper-content/
ADD *.yml /opt/data/workshopper-content/
ADD images /opt/data/workshopper-content/images
