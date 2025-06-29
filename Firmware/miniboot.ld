MEMORY
{
    ROM(rwx) : ORIGIN = 0, LENGTH = 64k
}

SECTIONS
{
    .text : {
        . = 0xf040;
        *(.bss)
        . = 0xf800;
        *(.text)
        . = 0xfffe;
        *(.vectors)
    } > ROM
}