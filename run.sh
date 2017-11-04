#!/bin/sh

run(){
    echo $@
    $@
}

genconf(){
    file=""
    if [ "$TYPE" == "" ]; then
        return 1
    elif [ "$TYPE" == "master" ] || [ "$TYPE" == "shadow" ]; then
        file=/etc/mfs/mfsmaster.cfg
    elif [ "$TYPE" == "chunk" ]; then
        file=/etc/mfs/mfschunkserver.cfg
    elif [ "$TYPE" == "meta" ]; then
        file=/etc/mfs/mfsmetalogger.cfg
    fi

    envvarcount=$(env | grep -c -e '^MFS_')
    if [ "$envvarcount" -gt "0" ]; then
        for envvar in $(env | grep -e "^MFS_"); do
            name=$(echo $envvar | cut -d '=' -f 1 | cut -c 5-)
            value=$(echo $envvar | cut -d '=' -f 2)
            filecount=$(grep -c "$name = " $file)
            if [ "$filecount" -gt "0" ]; then
        	    sed -e "s/$name = .*/$name = $value/g" -i $file
            else
                echo "$name = $value" >> $file
            fi
        done
    fi
    
    # auto use whatever volume set in /mnt/
    # ====================================================================================
    for mnt in $(ls /mnt/)
    do
        echo "Add mount $mnt"
        echo /mnt/$mnt >> /etc/mfs/mfshdd.cfg
    done

    echo "====================================================================================================="
    echo "Config $file:"
    cat $file | xargs --replace={} echo -e "\t{}"
    echo "Mounts /etc/mfs/mfshdd.cfg:"
    cat /etc/mfs/mfshdd.cfg | xargs --replace={} echo -e "\t{}"
    echo "====================================================================================================="
}

usage(){
    cat <<EOF
    Set MASTER_HOST env var to the IP Address of the LizardFS Master server
    Set MASTER_PORT env var to the Port of the LizardFS Master server	
    Set TYPE env var to trigger what type of server this docker should be:
            master server: -e TYPE=master 
             chunk server: -e TYPE=chunk  
            shadow server: -e TYPE=shadow   
        metalogger server: -e TYPE=meta  
           cgi web server: -e TYPE=cgi
    Any volume mounted to /mnt will automatically be added as Data Device for a chunk server, using something like: -v "/local_disk_to_use_as_chunk_disk/:/mnt/chunkDisk:rw" 
    To store the data of each server locally, just mount a local folder to /var/lib/mfs, using something like: -v "/local_lizard_server_data_path/:/var/lib/mfs:rw"
    When starting a server, any env var prefixed with MFS_ will be used in the server cfg file. ex: -e TYPE=chunk -e MFS_LABEL=0 -> will put LABEL=0 into /etc/mfs/mfschunkserver.cfg 	
    ex:
        docker run -d \\
            --restart=always \\
            --net=host \\
            -e TYPE=chunk \\
            -e MASTER_HOST=192.168.0.12 \\
            -v "/mnt/lizardfs_chunk1:/mnt/chunk1:rw" \\
            -v "/mnt/lizardfs_data_chunkserver:/var/lib/mfs:rw"  \\
            monsonnl/lizardfs:latest
=====================================================================================================

EOF

}

echo "====================================================================================================="
echo -e "container IP: $(ifconfig eth0 | grep 'inet ' | awk '{print $2}')\n" 

# setup required and default vars 
default_port=9419
default_host=mfsmaster
if [ "$TYPE" == "chunk" ]; then
    default_port=9420
fi
if [ "$MASTER_HOST" != "" ] ; then 
	export MFS_MASTER=$MASTER_HOST
fi
if [ "$MASTER_PORT" != "" ] ; then 
	export MFS_MASTER_PORT=$MASTER_PORT
fi
if [ "$MFS_MASTER" == "" ]; then
    export MFS_MASTER=$default_host
fi
if [ "$MFS_MASTER_PORT" == "" ] ; then 
	export MFS_MASTER_PORT=$default_port
fi
if [ "$TYPE" == "master" ] || [ "$TYPE" == "shadow" ]; then
    export MFS_PERSONALITY=$TYPE
fi
   
# if no /var/lib/mfs/metadata.mfs, we have to initiate a new one! (new install!)
if [ ! -f /var/lib/mfs/metadata.mfs ] ; then 
	cp /etc/mfs/metadata.mfs.empty /var/lib/mfs/metadata.mfs
fi

# Run the requested lizardfs server
# ====================================================================================
genconf
if [ "$TYPE" == "chunk" ] ; then 
	run mfschunkserver -d start
elif [ "$TYPE" == "master" ] || [ "$TYPE" == "shadow" ] ; then 
	run mfsmaster -d start
elif [ "$TYPE" == "meta" ] ; then 
	run mfsmetalogger -d
elif [ "$TYPE" == "cgi" ] ; then 
	extra=""
	[ "$PORT" != "" ] && extra=" -P $PORT"
	run /usr/sbin/lizardfs-cgiserver $extra
else
    usage
fi
