from diagrams import Diagram, Cluster, Edge
from diagrams.aws.compute import EC2
from diagrams.aws.storage import S3
from diagrams.aws.network import ALB
from diagrams.onprem.client import User

# creating the diagram
with Diagram("Lab4 AWS Architecture", show=True):

    # user coming from internet
    user = User("User")

    # s3 bucket for storage
    bucket = S3("Lab4 S3 Bucket")

    # main vpc
    with Cluster("Lab4 VPC"):

        # public subnet where load balancer lives
        with Cluster("Public Subnet"):
            load_balancer = ALB("Application Load Balancer")

        # private subnet for servers
        with Cluster("Private Subnet"):
            server1 = EC2("EC2 Instance A")
            server2 = EC2("EC2 Instance B")
            server3 = EC2("EC2 Instance C")

    # traffic flow
    user >> Edge(label="HTTP") >> load_balancer
    load_balancer >> Edge(label="Traffic to instances") >> [
        server1, server2, server3]
