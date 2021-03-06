#!/usr/bin/env bash
echo "*************************"
echo "*** Installing Django ***"
echo "*************************"

if [[ -z "$1" ]]
then
  echo "Django project name not set. Check the Vagrant file."
  exit 1
else
  DJANGO_PROJECT=$1
fi

# install packages
apt-get install -y python-setuptools libpq-dev python-dev g++ redis-server
easy_install pip

# install python packages
pip install -r /vagrant/requirements.txt
pip install django-debug-toolbar

# Set environment variables
if ! grep -Fq "DEBUG" /etc/environment
then
    sudo echo "DEBUG=TRUE" >> /etc/environment
    sudo echo "SOCIAL_AUTH_GOOGLE_OAUTH2_KEY='237400346062-fgmcf2r36vgqfh0nuisd8ofi8ot5nrp4.apps.googleusercontent.com'" >> /etc/environment
    sudo echo "SOCIAL_AUTH_GOOGLE_OAUTH2_SECRET='sKyWX8OQnuIWusn3WTFEevQt'" >> /etc/environment
    sudo echo "SECRET_KEY='LousyKeyOnlySuitableForDevEnvironments'" >> /etc/environment
    sudo echo "DATABASE_URL='postgres://$DJANGO_PROJECT:$DJANGO_PROJECT@localhost/$DJANGO_PROJECT'" >> /etc/environment
    . /etc/environment
    export DATABASE_URL
    export DEBUG
    export SECRET_KEY
    export SOCIAL_AUTH_GOOGLE_OAUTH2_KEY
    export SOCIAL_AUTH_GOOGLE_OAUTH2_SECRET
fi

# Create database
user_exists=`sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='$DJANGO_PROJECT'"`
db_exists=`sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='$DJANGO_PROJECT'"`

if [[ $user_exists != "1" ]]
then
    su postgres -c "createuser -w -d -r -s $DJANGO_PROJECT"
fi

sudo -u postgres psql -c "ALTER USER $DJANGO_PROJECT WITH PASSWORD '$DJANGO_PROJECT';"

if [[ $db_exists != "1" ]]
then
    su postgres -c "createdb -O $DJANGO_PROJECT $DJANGO_PROJECT"
fi

cd /vagrant
python manage.py migrate

# configure the django dev server as an upstart daemon
cp /vagrant/provision/django/django-server.conf /etc/init
if (( $(ps -ef | grep -v grep | grep "manage.py runserver" | wc -l) > 0 ))
then
    restart django-server
else
    start django-server
fi

# configure celery as an upstart daemon
cp /vagrant/provision/django/celery-server.conf /etc/init
if (( $(ps -ef | grep -v grep | grep "celery -A djaxelrod" | wc -l) > 0 ))
then
    restart celery-server
else
    start celery-server
fi
