function slurm_job_submit(job_desc)
    local cloud_price = get_cloud_price()
    if cloud_price < local_price then
        job_desc.partition = "cloud"
    end
    return slurm.SUCCESS
end
