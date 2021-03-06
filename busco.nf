nextflow.enable.dsl=2



params.odb = 'lepidoptera_odb10,nematoda_odb10'
params.busco_downloads = './busco_downloads'
params.genomes = './data/*fasta.gz'
params.outdir = './results'



busco_dbs = Channel.of(params.odb.split(','))

busco_db_dir = file(params.busco_downloads)

genomes = Channel
                .fromPath(params.genomes, checkIfExists: true)
                .map { file -> tuple(file.simpleName, file) }




geno_busco = genomes.combine(busco_dbs)



process busco {
    tag "${species}_${busco_db}"
    publishDir "$params.outdir/${species}_${busco_db}", mode: 'link'

    input:
      tuple val(species), path(genome), val(busco_db)
      path busco_db_dir

    output:
      path "${species}_${busco_db}_*"

    script:
      """
      if [ -f *.gz ]; then
            gunzip -c $genome > assembly.fasta
        else
            ln $genome assembly.fasta
      fi
      export AUGUSTUS_CONFIG_PATH=augustus_conf
      cp -r /augustus/config/ \$AUGUSTUS_CONFIG_PATH
      busco -c ${task.cpus} -l $busco_db -i assembly.fasta --out run_busco --mode geno
      mv run_busco/short_summary* ${species}_${busco_db}_short_summary.txt
      mv run_busco/run_*/full_table.tsv ${species}_${busco_db}_full_table.tsv
      for ext in .faa .fna; do
        seqFile=${species}_${busco_db}_single_copy_busco_sequences\$ext
        for file in run_busco/run_nematoda_odb10/busco_sequences/single_copy_busco_sequences/*\$ext; do
          echo \">\$(basename \${file%\$ext})\" >> \$seqFile; tail -n +2 \$file >> \$seqFile;
        done
      done
      rm -rf \$AUGUSTUS_CONFIG_PATH run_busco/ assembly.fasta
      """
}

workflow {
    busco(geno_busco, busco_db_dir)
}