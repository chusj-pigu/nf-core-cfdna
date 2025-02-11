/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { paramsSummaryMap       } from 'plugin/nf-schema'
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText } from '../subworkflows/local/utils_nfcore_cfdna_pipeline'
include { CHOPPER_LENGTH         } from '../modules/local/chopper/main.nf'
include { MINIMAP2_ALIGN         } from '../modules/local/minimap2/main.nf'
include { SAMTOOLS_TOBAM         } from '../modules/local/samtools/main.nf'
include { SAMTOOLS_SORT          } from '../modules/local/samtools/main.nf'
include { SAMTOOLS_INDEX         } from '../modules/local/samtools/main.nf'
include { HMMCOPY_WIG } from '../modules/local/ichorcna/main.nf'
include { ICHORCNA_DOWNLOAD } from '../modules/local/ichorcna/main.nf'
include { ICHORCNA } from '../modules/local/ichorcna/main.nf'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow CFDNA {

    take:
    ch_samplesheet_red // channel: samplesheet read in from --input
    max_length
    qual
    ref
    ch_samplesheet_purity
    main:

    ch_versions = Channel.empty()

    //
    // Collate and save software versions
    //
    softwareVersionsToYAML(ch_versions)
        .collectFile(
            storeDir: "${params.outdir}/pipeline_info",
            name: 'nf_core_'  +  'cfdna_software_'  + 'versions.yml',
            sort: true,
            newLine: true
        ).set { ch_collated_versions }

    CHOPPER_LENGTH(ch_samplesheet_red, max_length, qual)

    ch_reads_filt = CHOPPER_LENGTH.out.reads
        .combine(ref)

    MINIMAP2_ALIGN(ch_reads_filt)

    SAMTOOLS_TOBAM(MINIMAP2_ALIGN.out.sam)
    SAMTOOLS_SORT(SAMTOOLS_TOBAM.out.bamfile)
    SAMTOOLS_INDEX(SAMTOOLS_SORT.out.sortedbam)

    HMMCOPY_WIG(SAMTOOLS_INDEX.out.bamfile_index)

    wig_purity_ch = HMMCOPY_WIG.out.wig
        .join(ch_samplesheet_purity)

    ICHORCNA_DOWNLOAD(wig_purity_ch)
    ICHORCNA(ICHORCNA_DOWNLOAD.out.seq_info)


    emit:
    versions       = ch_collated_versions                // channel: [ path(versions.yml) ]
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
