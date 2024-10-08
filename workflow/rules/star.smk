rule fastqc:
    """Assess the FASTQ quality using FastQC BEFORE TRIMMING"""
    input:
        fq1 = os.path.join(config["path"]["fastq_dir"], "{id}_R1_001.220405.A00516.AHVHTNDSX2.fastq.gz"),
        fq2 = os.path.join(config["path"]["fastq_dir"], "{id}_R2_001.220405.A00516.AHVHTNDSX2.fastq.gz")
    output:
        qc_fq1_out = "data/qc/{id}_R1_001.220405.A00516.AHVHTNDSX2_fastqc.html",
        qc_fq2_out = "data/qc/{id}_R2_001.220405.A00516.AHVHTNDSX2_fastqc.html"
    params:
        out_dir = "data/qc"
    log:
        "logs/fastqc_{id}.log"
    threads: 8
    conda:
        "envs/fastqc.yml" 
    shell:
        "mkdir -p {params.out_dir} && "
        "fastqc --outdir {params.out_dir} --format fastq --threads {threads} {input.fq1} {input.fq2} &> {log}"

# Règle pour le trimming avec trim_galore
rule trim_reads:
    input:
        fq1 = os.path.join(config["path"]["fastq_dir"], "{id}_R1_001.220405.A00516.AHVHTNDSX2.fastq.gz"),
        fq2 = os.path.join(config["path"]["fastq_dir"], "{id}_R2_001.220405.A00516.AHVHTNDSX2.fastq.gz")
    output:
        gal_trim1 = "data/trim_galore/{id}_R1_001.220405.A00516.AHVHTNDSX2_val_1.fq.gz", # les fichiers validés par trim_galore
        gal_trim2 = "data/trim_galore/{id}_R2_001.220405.A00516.AHVHTNDSX2_val_2.fq.gz"  
    threads:
        8
    conda:
        "envs/trim_galore.yml"
    log:
        "logs/trim_{id}.log"
    shell:
        """
        trim_galore --paired {input.fq1} {input.fq2} \
        --output_dir data/trim_galore --gzip \
        &> {log}
        """


rule qc_fastq:
    """ Assess the FASTQ quality using FastQC AFTER TRIMMING"""
    input:
        trimm_fq1 = rules.trim_reads.output.gal_trim1,
        trimm_fq2 = rules.trim_reads.output.gal_trim2,
#        trimm_unpaired_fq1 = rules.trim_reads.output.unpaired1,
#        trimm_unpaired_fq2 = rules.trim_reads.output.unpaired2
    output:
        qc_trimm_fq1_out = "data/qc_trim_galore/{id}_R1_001.220405.A00516.AHVHTNDSX2_val_1_fastqc.html",
        qc_trimm_fq2_out = "data/qc_trim_galore/{id}_R2_001.220405.A00516.AHVHTNDSX2_val_2_fastqc.html"
    params:
        out_dir = "data/qc_trim_galore"
    log:
        "logs/qc_trim_galore/{id}.log"
    threads:
        8
    conda:
        "envs/fastqc.yml"
    shell:
        "fastqc "
        "--outdir {params.out_dir} "
        "--format fastq "
        "--threads {threads} "
        "{input.trimm_fq1} {input.trimm_fq2} "
#        "{input.trimm_unpaired_fq1} {input.trimm_unpaired_fq2} "
        "&> {log}"



rule star_index:
    """ Generates the genome index for STAR """
    input:
        fasta = rules.download_human_genome.output.genome,
        gtf = config['download']['human_gtf']        #GRCh38.p14 reference
    output:
        chrNameLength = config['path']['chrNameLength']
    params:
        dir = config['path']['star_index']
    log:
        "logs/STAR/index.log"
    conda:
        "envs/star.yml"
    threads:
        8
    shell:
        "mkdir -p {params.dir} && "
        "STAR --runThreadN {threads} "
        "--runMode genomeGenerate "
        "--genomeDir {params.dir} "
        "--genomeFastaFiles {input.fasta} "
        "--sjdbGTFfile {input.gtf} "
        "--sjdbOverhang 99"
        "&> {log}"

rule star_alignreads:
    """ Generates a bam file using STAR """
    input:
        idx = rules.star_index.output,
        fq1 = rules.trim_reads.output.gal_trim1,
        fq2 = rules.trim_reads.output.gal_trim2
    output:
        bam = "results/STAR/{id}/Aligned.sortedByCoord.out.bam",
        bam_logs = "results/STAR/{id}/Log.final.out"
    params:
        index = config['path']['star_index'],
        output_dir = "results/STAR/{id}/"
    log:
        "logs/STAR/{id}.log"
    threads:
        8
    conda:
        "envs/star.yml"
    shell:
        "STAR --runMode alignReads "
        "--genomeDir {params.index} "
        "--readFilesIn {input.fq1} {input.fq2}  "
        "--runThreadN {threads} "
        "--readFilesCommand zcat "
        "--outReadsUnmapped Fastx "
        "--outFilterType BySJout "
        "--outStd Log "
        "--outSAMunmapped None "
        "--outSAMtype BAM SortedByCoordinate "
        "--outFileNamePrefix {params.output_dir} "
        "--outFilterScoreMinOverLread 0.3 "
        "--outFilterMatchNminOverLread 0.3 "
        "--outFilterMultimapNmax 100 "
        "--winAnchorMultimapNmax 100 "
        "--limitBAMsortRAM 15000000000 " ## 15 Go RAM
        "--outTmpDir /home/anthony/temp "  #### Causera des problemes
        "&> {log}"


