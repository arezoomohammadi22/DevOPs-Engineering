## Explanation
mysql-0 is the master:
Creates a replica_user
Grants replication privileges
mysql-1 and mysql-2 are replicas:
Connect to mysql-0
Start replication using CHANGE MASTER TO
##Verify Replication
After deploying, check the MySQL replication status:

On the master (mysql-0)

'''bash
kubectl exec -it mysql-0 -- mysql -uroot -prootpassword -e "SHOW MASTER STATUS;"
'''

On a replica (mysql-1 or mysql-2)
'''bash

kubectl exec -it mysql-1 -- mysql -uroot -prootpassword -e "SHOW SLAVE STATUS\G"
'''
If replication is working correctly, you should see:

Slave_IO_Running: Yes
Slave_SQL_Running: Yes
