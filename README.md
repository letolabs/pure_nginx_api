# Pure Nginx API

Why waste time and memory spinning up dynamic language interpreters when you can respond in less than 200ms?

## Example JSON API implemented in "pure" Nginx (Openresty) and Postgres

# Installation

This repository uses vagrant, to take it for a spin:

  ```vagrant up local```
  
This is a good time to go for a coffee or make some food. It will take up to 15 minutes or longer the first time, depending on if you have some of the dependencies already, your network speed and the phase of the moon.
  
After a few minutes, you should be able to

  ```curl -vi http://openresty.virtual/api/v1/health```
  
and get a valid JSON response


