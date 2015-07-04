#!/usr/bin/env bash

# Ensure apt-get doesn't ask us any annoying questions
export APPLOGDIR=/var/log/pure_nginx
export DEBIAN_FRONTEND=noninteractive
export SYSCTLLOG=$APPLOGDIR/sysctl.log
export APTLOG=$APPLOGDIR/apt-get.log
export SITEPIPLOG=$APPLOGDIR/site-pip.log
export TZLOG=$APPLOGDIR/tz.log
export UWSGILOG=$APPLOGDIR/uwsgi.log
export PGLOG=$APPLOGDIR/pg.log
export VIRTUALENVLOG=$APPLOGDIR/virtualenv.log
export OPENRESTYLOG=$APPLOGDIR/openresty.log
export APP=app
export WORKON_HOME=/home/$APP/.virtualenvs
export PROJECT_HOME=/home/$APP/workspace
export PYENVLOG=$APPLOGDIR/pyenv.log

mkdir -p $APPLOGDIR

echo "Updating apt index"
/usr/bin/apt-get update >> $APTLOG 2>&1
/usr/bin/apt-get install -y debconf-utils >> $APTLOG 2>&1

### Install Dependencies

echo "Installing lots of bits"
# Note that we are installing nginx-full to get all the init files/etc
# that it comes with. Later on we will switch to using the openresty conf dir
# and binaries
/usr/bin/apt-get install -y build-essential curl openntpd dnsutils git-core \
    apt-file htop ack-grep redis-server redis-tools monit \
    libffi-dev libssl-dev \
    python python-dev python-pip openssh-client openssh-server \
    libpcre3-dev nginx-full libpq-dev postgresql-server-dev-9.4 \
    ssh tzdata vim vim-runtime postgresql-9.4 >> $APTLOG 2>&1

#### TIME SETUP ####
echo "America/Los_Angeles" > /etc/timezone
/usr/sbin/dpkg-reconfigure -f noninteractive tzdata &> $TZLOG

# TODO: use tlsdate instead
NTP=2.pool.ntp.org
/usr/sbin/ntpdate $NTP

export PYENV_ROOT="/home/$APP/.pyenv"
echo "Installing pyenv"
git clone https://github.com/yyuu/pyenv.git $PYENV_ROOT >> $PYENVLOG 2>&1

pushd $PYENV_ROOT      >> $PYENVLOG 2>&1
git checkout v20150601 >> $PYENVLOG 2>&1
popd                   >> $PYENVLOG 2>&1

export PATH="$PYENV_ROOT/bin:$PATH"
export PYENV_VERSION="2.7.10"
echo "Installing Python $PYENV_VERSION"

pyenv install 2.7.10   >> $PYENVLOG 2>&1
pyenv rehash           >> $PYENVLOG 2>&1
pyenv versions         >> $PYENVLOG 2>&1
eval "$(pyenv init -)" >> $PYENVLOG 2>&1
hash                   >> $PYENVLOG 2>&1

echo "Installing things in the system Python: virtualenv(wrapper), uwsgi + pgcli"
pip install uwsgi virtualenv virtualenvwrapper pgcli sqlalchemy >> $SITEPIPLOG 2>&1

if [ -z "`grep $APP: /etc/passwd`"]; then
       useradd $APP
       adduser $APP www-data
       # install our custom bash config so we can use pyenv+virtualenv
       cp /vagrant/config/openresty.bashrc /home/$APP/.bashrc
       ln -s /home/$APP/openresty.bashrc /home/$APP/.bash_profile
       chown -R $APP:$APP /home/$APP
       chown -R $APP:$APP $APPLOGDIR
fi


echo "Configuring PostgreSQL"
sudo -E -u postgres psql -f /vagrant/provision.sql >> $PGLOG 2>&1

echo "Running user provision stuff as $APP"
sudo -E -u $APP /vagrant/scripts/vagrant_provision_user.sh

echo "Inserting local dev SQL data"
sudo -E -u postgres psql -f /vagrant/data/local.sql $APP >> $PGLOG 2>&1

# Start up the uWSGI middle-ware
cd /var/api
echo "Starting uWSGI..."
uwsgi --uid $APP --gid $APP -s /tmp/uwsgi.sock -w $APP:app -H $WORKON_HOME/$APP --chmod-socket=666 --stats 127.0.0.1:9191 >> $UWSGILOG 2>&1 &

# If we don't do this, the copy of nginx in memory is different than the one on
# disk and fucks shit up
/etc/init.d/nginx stop

echo "Installing OpenResty Nginx flavor with Postgres module + friends"
/vagrant/scripts/openresty_provision.sh >> $OPENRESTYLOG 2>&1

# backup the plain nginx binary and conf dir in case we want to compare them
echo "Backing up plain nginx stuff"
mv /usr/sbin/nginx{,.bak}
mv /etc/nginx{,.bak}

echo "Over-riding system nginx binary+conf with Openresty flavor"
ln -sf /usr/local/openresty/nginx/sbin/nginx /usr/sbin/nginx
ln -sf /usr/local/openresty/nginx/conf /etc/nginx

mkdir -p /etc/nginx/sites-{available,enabled}

echo "Installing nginx config"
cp /vagrant/config/nginx/*.conf /etc/nginx/

echo "Installing sysctl.conf"
cp /vagrant/config/sysctl.conf /etc/sysctl.conf
sysctl -p /etc/sysctl.conf &>$SYSCTLLOG

echo "Copying authorized_keys"
mkdir -p /home/$APP/.ssh
cp /vagrant/config/authorized_keys /home/$APP/.ssh/

# TODO: How to pass in env vars to vagrant from our host VM?
# if no env is defined, assume vagrant
if [ "x$APP_ENV" = "x" ]; then
	export APP_ENV="virtual"
	export APP_URL="openresty.virtual"
fi

NGINX=`/etc/init.d/nginx status | grep 'is running'`
if [ -z "$NGINX" ]; then
    service nginx restart
else
    service nginx start
fi
