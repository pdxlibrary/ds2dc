# DSpace to Digital Commons Migration

This is the process we followed for each DSpace Collection that was to be migrated directly to Digital Commons.


### Prerequisites
- A web server that is configured to allow access to the IP range for Digital Commons servers (72.5.9.0/255.255.255.0)
- Ruby and the bundler gem
- Command-line access to your DSpace server


### Process

In the command examples, I am exporting the files to the document root of the DSpace reverse-proxy web server.

0. From the DSpace web interface, export the collection's metadata to a CSV file.

0. From the command line, export the collection to a directory.  

    ```
    mkdir -p /var/www/html/dspace-exports/psu/8756  
    $DSPACE_HOME/bin/dspace export -m \  
    -d /var/www/html/dspace-exports/psu/8756 \  
    -i psu/8756 -n 1 -t COLLECTION  
    ```

0. Rename the subdirectories in the export to match their item IDs.  

    ```
    ruby rename-exported-bundles.rb -b /var/www/html/dspace-exports/psu/8756
    ```

0. Run the migrate script to generate the Digital Commons CSV file (metadata) and file location.  

    ```
    ruby migrate.rb \  
      -m psu-8756.csv \  
      -e /var/www/html/dspace-exports/psu/8756 \  
      -c 8756 -u http://static.library.pdx.edu/dr-transfer/psu  
    ```  

0. Submit the resulting CSV file to Digital Commons for import.
0. After you receive notice that everything was processed, clean up the resulting mess.
