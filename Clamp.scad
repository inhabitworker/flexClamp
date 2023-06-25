// Input Parameters

/* [ General ] */ 

// The print-in-place clearance, your printer configuration may be capable of less or more. Default 0.3mm is the typical choice.
    Clearance = 0.3; // [0 : 0.05 : 0.5]

/* [ Plates ] */

// The width of the plates doubles as the depth of the spring, as their extent forms the first layer of printing.
    Width = 10;

// The length of a plate extending into the interior of the circle/spring. Limited by spring radius.
    InteriorLength = 5;
// The length of a plate as it extends outwards. Arbitrary.
    ExteriorLength = 5;

// Thickness of the plates. This informs the angle of our spring opening.
    PlateThickness = 3;

// The initial gap between the plate and the axis mirroring them (i.e. 2*this = gap between plates).
    Gap = 1;

/* [ Spring ] */

// The radius of the spring circle.
    Radius = 15;

// The overall thickness of the spring body. This will inform the radius of the revolute joints with plate.
    Thickness = 5;

// The number of layers interior to the spring. We would like the thickness of these to be more than the slicer wall thickness. 
    Frequency = 3; // [0 : 1 : 100]


// [* Hidden *]
    $fs = 0.5;
    Overlap = 0.1;

// I made this to use with an ADXL345 board. You may well not care an iota for this. lol
    ADXL345 = false;


// Computed Parameters

// Information about the spring's opening.
    InternalRadius = Radius - Thickness/2;

    ScrewRad = Thickness/2 - 2*Clearance;
    RodRad = ScrewRad - Clearance;

    OpeningAngle = asin((PlateThickness + Gap + Thickness/2) / InternalRadius);
    OpeningTerminalX = sin(OpeningAngle) * InternalRadius;
    OpeningTerminalY = cos(OpeningAngle) * InternalRadius;

    OpeningR = [OpeningTerminalX, -OpeningTerminalY, 0];
    OpeningL = [-OpeningTerminalX, -OpeningTerminalY, 0];

    ChannelCut = Width/2;




module Sector() {
    SectorX = sin(OpeningAngle) * 2 * Radius;
    SectorY = cos(OpeningAngle) * 2 * Radius;
    translate([0,0,- Width/2 - Overlap])
    linear_extrude(Width+ 2*Overlap) 
    polygon([
        [0,0], 
        [SectorX, -SectorY], 
        [-Radius-Overlap, -SectorY], 
        [-Radius-Overlap, Radius+Overlap],
        [-Overlap, Radius+Overlap]
        ], [[0,1,2,3,4]]);
}

module ChannelOpening() {
    translate([OpeningTerminalX, -OpeningTerminalY,0])
    rotate(OpeningAngle)
    intersection() {
        cylinder(ChannelCut, Thickness/2+Overlap, Thickness/2+Overlap, center=true);

        // The cutter - must be a better way lol.
        translate([-Thickness/2 - Overlap,0,0])
        rotate([90,0,0])
        translate([0,0,-Thickness])
        linear_extrude(2*Thickness)
        polygon([
            [0, ChannelCut/2],
            [0, -ChannelCut/2],
            [Thickness+2*Overlap,  -ChannelCut/2],
            [Thickness+2*Overlap, 0],
        ],[[0,1,2,3]]);
    }

}

module SpringLayering() {
    // Calculating amount based on frequency, then cutting the sector and
    // endcaps
    // Then not mirroring lol!
    
    // Need space for outer 2, plus extra lines n and n+1 spaces
    // we're really just drawing gaps to remove

    // if frequency is 1, solid, if two, a gap. if more, more layers.

    if(Frequency == 0) {
    } else {
        // Endcap Cut
        difference() {
            // Halvening 
            difference() {
                union() {
                    LayerThickness = Thickness/(Frequency-0.5);

                    for(i = [0 : 1 : Frequency-2]) {
                        OuterRadius = Radius - i*LayerThickness-LayerThickness/2;
                        InnerRadius = Radius - ((i+1)*LayerThickness);

                        difference() {
                            cylinder(Width + Overlap, OuterRadius, OuterRadius, center=true);
                            cylinder(Width + 2*Overlap, InnerRadius, InnerRadius, center=true);
                        }
                    }
                }

                translate([-2*Radius-2*Overlap,-Radius,-Radius/2])
                cube(Radius*2);
            }

            translate(OpeningR)
            cylinder(Width + 3*Overlap, Thickness, Thickness, center=true);
        }
    }
}

module Spring() {
    // Channel Cutout
    difference() {
        // Core Channel 
        difference() {
            // Opening Caps
            union() {
                // Opening Sector & Half Cut 
                difference() {
                    // Base Loop
                    difference() {
                        cylinder(Width, Radius, Radius , center = true);
                        cylinder(Width+1, Radius - Thickness, Radius - Thickness, center = true);
                    };

                    Sector();
                }

                translate(OpeningR)
                cylinder(Width, Thickness/2, Thickness/2, center=true);
            }

            translate(OpeningR) 
            cylinder(Width+0.2, ScrewRad, ScrewRad, center=true);
        }

        ChannelOpening();
        SpringLayering();
    }
}

module PlateRod() {
    // Expansion Prevent Sliding

    translate(OpeningR)
    union() {
        // Base Rod
        cylinder(Width, RodRad, RodRad, center=true);
        translate([0,0,-ChannelCut/2 + Clearance])

        cylinder(ChannelCut/4, RodRad, Thickness/2- Clearance, center=true);

        translate([0,0,-ChannelCut/2 + ChannelCut/4 + Clearance])
        cylinder(ChannelCut/4, Thickness/2 - Clearance, Thickness/2 - Clearance, center=true);
    }
}

module Plate() {
    // Plate makes ingress on rod.
    Span = PlateThickness - RodRad/2;
    // Add Rods
    union() {
        translate([OpeningTerminalX, -OpeningTerminalY, 0])
        difference() {
            translate([- 3*PlateThickness/4,0,0])
            union() {
                cube([PlateThickness, 10, Width], center=true);

                // Connection to rod
                translate([-PlateThickness/2,-ChannelCut/2,-Width/2])
                cube([PlateThickness + 3*PlateThickness/4 + Overlap - Thickness/4, ChannelCut, Width]);

            }

            cylinder(Width + Overlap, Thickness/2+Clearance, Thickness/2+Clearance);

            translate([0,0,-Width/2])
            cylinder((Width - ChannelCut + 1), Thickness/2+Clearance, Thickness/2+Clearance, center=true);
        }

        PlateRod();
    }
}


module Clamp() {
    union() {
        Spring();
        mirror([1,0,0])
        Spring();
    }

    Plate();
    mirror([1, 0, 0]) {
       Plate();
    }
    
} 

Clamp();

